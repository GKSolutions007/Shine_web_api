/* =====================================================================================
   04_Secret_Storage.sql  -  P1: stop storing / returning secrets in readable form
   -------------------------------------------------------------------------------------
   Run on each Shine database AFTER 01-03 and after deploying the matching API/UI build.
   Safe to re-run. Parameter lists and result column positions are unchanged.

   1. uspManageApplicationConfig
      - Mode 1 no longer returns the SMTP password (it went to the browser through
        api/applicationconfig/get and to anyone through api/validatepermissions).
      - Mode 2 only replaces the SMTP password when a new one is given (blank = keep).
      Application action passwords (tblAppPasswordSettings) are now PBKDF2 hashes written by the
      API; old encrypted values keep working and are upgraded on first use or by
      Deploy\Migrate-LegacyPasswords.ps1.
   2. Device / user verification OTPs (tblOTPVerification, uspManageOTP)
      - stored as a salted SHA-256 hash instead of the OTP itself
      - at most 5 wrong attempts per OTP, and an OTP can be used only once
      - result shapes unchanged (error = one column with the message, success = row + WebDevices)
   3. tblMobileLogin.ConnectionString is never written by the current code: old values are
      removed and uspLoginInfoRecieve returns NULL in that column (same column position).

   Rollback: re-create the previous procedures from the script.ipynb export. The new
   tblOTPVerification columns can stay.
   ===================================================================================== */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------- 1. uspManageApplicationConfig ---------- */
DECLARE @def nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageApplicationConfig'));
IF @def IS NULL THROW 50001, N'dbo.uspManageApplicationConfig not found.', 1;
IF @def NOT LIKE N'%-- P1: secret not returned%'
BEGIN
    DECLARE @old1 nvarchar(200) = N'SELECT CaseType,Confirmpopup,Roundoff,RoundoffValue,SMTPHost,EMail,Password,DecimalValues,ThemeID,';
    DECLARE @new1 nvarchar(300) = N'SELECT CaseType,Confirmpopup,Roundoff,RoundoffValue,SMTPHost,EMail,CAST(NULL AS nvarchar(max)) AS Password /* -- P1: secret not returned */,DecimalValues,ThemeID,';
    DECLARE @old2 nvarchar(200) = N'UPDATE tblAppConfig SET AppValue = @Password where AppID = 7';
    DECLARE @new2 nvarchar(300) = N'UPDATE tblAppConfig SET AppValue = @Password where AppID = 7 AND @Password IS NOT NULL -- blank = keep';
    IF CHARINDEX(@old1, @def) = 0 OR CHARINDEX(@old2, @def) = 0
        THROW 50002, N'uspManageApplicationConfig differs from the expected version; change it by hand (see the comments in this script).', 1;
    SET @def = REPLACE(REPLACE(@def, @old1, @new1), @old2, @new2);
    SET @def = STUFF(@def, PATINDEX(N'%CREATE%PROC%', @def), LEN(N'CREATE'), N'CREATE OR ALTER');
    EXEC sys.sp_executesql @def;
    PRINT N'uspManageApplicationConfig updated';
END
GO

/* ---------- 2. OTPs ---------- */
IF COL_LENGTH(N'dbo.tblOTPVerification', N'OtpSalt') IS NULL
    ALTER TABLE dbo.tblOTPVerification ADD OtpSalt varbinary(16) NULL;
IF COL_LENGTH(N'dbo.tblOTPVerification', N'Attempts') IS NULL
    ALTER TABLE dbo.tblOTPVerification ADD Attempts tinyint NOT NULL CONSTRAINT DF_tblOTPVerification_Attempts DEFAULT 0;
IF COL_LENGTH(N'dbo.tblOTPVerification', N'OTP') BETWEEN 1 AND 128 * 2 - 1   -- (-1 = nvarchar(max): leave it)
    ALTER TABLE dbo.tblOTPVerification ALTER COLUMN OTP nvarchar(128) NULL;
GO
-- Old rows hold readable OTPs (all expired after 10 minutes): remove the values.
UPDATE dbo.tblOTPVerification SET OTP = NULL WHERE OtpSalt IS NULL AND OTP IS NOT NULL;
GO

--uspManageOTP 2,146,'',567384
CREATE OR ALTER PROCEDURE [dbo].[uspManageOTP]
@Mode int,@ID INT = 0,@OTPFrom nvarchar(50) = null,@OTP NVARCHAR(15) = null ,@UserID int = 9
AS
BEGIN
SET NOCOUNT ON;
declare @reqtime datetime = getdate();
declare @exptime datetime = dateadd(MINUTE,10,@reqtime)
IF(@Mode = 1)
BEGIN
    -- Only a salted hash of the OTP is stored.
    DECLARE @salt varbinary(16) = CRYPT_GEN_RANDOM(16);
    INSERT INTO tblOTPVerification (OTPFrom, OTP, RequestDate, ExpiryDate, UserID, OtpSalt, Attempts)
    VALUES (@OTPFrom, CONVERT(nvarchar(128), HASHBYTES('SHA2_256', @salt + CAST(LTRIM(RTRIM(@OTP)) AS varbinary(64))), 2),
            @reqtime, @exptime, @UserID, @salt, 0);
    SELECT SCOPE_IDENTITY();
END
IF(@Mode = 2)
BEGIN
    DECLARE @stored nvarchar(128), @rowSalt varbinary(16), @attempts tinyint, @exp datetime;
    SELECT @stored = OTP, @rowSalt = OtpSalt, @attempts = Attempts, @exp = ExpiryDate
    FROM tblOTPVerification WHERE ID = @ID;
    IF @stored IS NULL OR @rowSalt IS NULL
    BEGIN
        SELECT 'Invalid OTP';
        RETURN;
    END
    IF @attempts >= 5
    BEGIN
        SELECT 'Too many wrong attempts. Please request a new OTP';
        RETURN;
    END
    IF @stored <> CONVERT(nvarchar(128), HASHBYTES('SHA2_256', @rowSalt + CAST(LTRIM(RTRIM(ISNULL(@OTP, N''))) AS varbinary(64))), 2)
    BEGIN
        UPDATE tblOTPVerification SET Attempts = Attempts + 1 WHERE ID = @ID;
        SELECT 'Invalid OTP';
        RETURN;
    END
    IF @exp < GETDATE()
    BEGIN
        SELECT 'The OTP you entered has expired. Please request a new OTP';
        RETURN;
    END
    -- one-time use: the OTP stops working once it has been accepted
    UPDATE tblOTPVerification SET ExpiryDate = GETDATE() WHERE ID = @ID;
    SELECT ID, OTPFrom, RequestDate, ExpiryDate, UserID, (SELECT TOP (1) WebDevices FROM tblCompanyRegistration) WebDevices
    FROM tblOTPVerification WHERE ID = @ID;
END
END
GO

/* ---------- 3. tblMobileLogin.ConnectionString ---------- */
UPDATE dbo.tblMobileLogin SET ConnectionString = NULL WHERE ConnectionString IS NOT NULL;
GO
DECLARE @def nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspLoginInfoRecieve'));
IF @def IS NULL THROW 50003, N'dbo.uspLoginInfoRecieve not found.', 1;
IF @def NOT LIKE N'%-- P1: no ConnectionString%'
BEGIN
    -- same columns and order as SELECT *, with ConnectionString always NULL
    DECLARE @cols nvarchar(max) = N'ID,LoginTime,LogoutTime,IPAddress,DeviceName,TokenValue,CAST(NULL AS nvarchar(max)) AS ConnectionString,UserID,DataBaseName,SessionStatus,DeviceID /* -- P1: no ConnectionString */';
    IF (SELECT STRING_AGG(name, ',') WITHIN GROUP (ORDER BY column_id) FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.tblMobileLogin'))
       <> N'ID,LoginTime,LogoutTime,IPAddress,DeviceName,TokenValue,ConnectionString,UserID,DataBaseName,SessionStatus,DeviceID'
        THROW 50004, N'tblMobileLogin columns differ from the expected list; change uspLoginInfoRecieve by hand.', 1;
    SET @def = REPLACE(@def, N'select * from tblMobileLogin where', N'select ' + @cols + N' from tblMobileLogin where');
    SET @def = STUFF(@def, PATINDEX(N'%CREATE%PROC%', @def), LEN(N'CREATE'), N'CREATE OR ALTER');
    EXEC sys.sp_executesql @def;
    PRINT N'uspLoginInfoRecieve updated';
END
GO
