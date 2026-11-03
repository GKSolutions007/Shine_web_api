/* =====================================================================================
   02_Account_Security.sql  -  P0 fix: account takeover through forgot-password / user APIs
   -------------------------------------------------------------------------------------
   Run on each Shine database (SSMS or sqlcmd), AFTER deploying the matching API build.
   Safe to re-run (CREATE OR ALTER / IF NOT EXISTS).

   What it changes
   1. New table dbo.tblPasswordResetOtp + procedure dbo.uspPasswordResetOtp.
      The forgot-password OTP is now created, stored (as a PBKDF2 hash) and checked on the
      server. Before, the API returned the OTP to the browser and the browser compared it,
      so anyone could call forgotpassword/setpassword directly and reset any password.
   2. dbo.uspManageUsers (parameter list and order unchanged - the API binds by position):
      - Mode 9 (reset password) only works after the OTP was verified on the server in the
        last 15 minutes, and uses that verification once. Returns Updated = 1/0.
      - Mode 8 returns only the user ID (was SELECT *, including the password hash).
      - Modes 3 and 4 no longer return the Password column (Mode 4 is sent to the browser
        by api/validatepermissions).
      - Mode 2 keeps the current password when @Password is NULL (the API already sends NULL
        for "unchanged"; the old code wrote NULL into the column) and no longer copies the
        password hash into tblMasterHistory.
      - Mode 5 (account activation link) only activates a self-registered account that was
        never activated or edited; it can no longer re-activate a user an admin disabled.
   3. Removes password values that Mode 2 had already copied into tblMasterHistory.

   Rollback: re-create the previous dbo.uspManageUsers from source control / the
   script.ipynb export. The new table can stay (it is only used by the new procedure).
   ===================================================================================== */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.tblPasswordResetOtp', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.tblPasswordResetOtp
    (
        ID          int IDENTITY(1,1) NOT NULL CONSTRAINT PK_tblPasswordResetOtp PRIMARY KEY,
        UserID      smallint      NOT NULL,
        OtpHash     nvarchar(200) NOT NULL,      -- PasswordHasher (PBKDF2) hash, never the OTP
        CreatedAt   datetime2(0)  NOT NULL CONSTRAINT DF_tblPasswordResetOtp_CreatedAt DEFAULT SYSUTCDATETIME(),
        ExpiresAt   datetime2(0)  NOT NULL,
        Attempts    tinyint       NOT NULL CONSTRAINT DF_tblPasswordResetOtp_Attempts DEFAULT 0,
        VerifiedAt  datetime2(0)  NULL,
        ConsumedAt  datetime2(0)  NULL
    );
    CREATE INDEX IX_tblPasswordResetOtp_UserID ON dbo.tblPasswordResetOtp (UserID, CreatedAt DESC);
END
GO

/* Mode 1  create  (@UserName, @EMailID, @OtpHash) -> UserID, OtpID, Status
                    Status 1 = created, -1 = too many requests. No row = unknown user/e-mail.
   Mode 2  active OTP for verification (@UserName, @EMailID) -> OtpID, OtpHash, Attempts
   Mode 3  wrong OTP entered (@OtpID): counts the attempt (5 wrong attempts end the OTP)
   Mode 4  OTP verified (@OtpID): allows one password reset in the next 15 minutes      */
CREATE OR ALTER PROCEDURE dbo.uspPasswordResetOtp
    @Mode int,
    @UserName nvarchar(256) = NULL,
    @EMailID nvarchar(320) = NULL,
    @OtpHash nvarchar(200) = NULL,
    @OtpID int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @now datetime2(0) = SYSUTCDATETIME(), @UserID smallint;

    IF @Mode IN (1, 2)
        SELECT @UserID = ID FROM dbo.tblUsers
        WHERE Active = 1 AND UserName = @UserName AND EMailID = LOWER(@EMailID);

    IF @Mode = 1
    BEGIN
        IF @UserID IS NULL OR @OtpHash IS NULL RETURN;
        -- at most 5 OTP e-mails per user per hour
        IF (SELECT COUNT(*) FROM dbo.tblPasswordResetOtp WHERE UserID = @UserID AND CreatedAt > DATEADD(HOUR, -1, @now)) >= 5
        BEGIN
            SELECT @UserID AS UserID, CAST(NULL AS int) AS OtpID, -1 AS Status;
            RETURN;
        END
        BEGIN TRAN;
            -- a new OTP replaces any earlier unused one
            UPDATE dbo.tblPasswordResetOtp SET ConsumedAt = @now WHERE UserID = @UserID AND ConsumedAt IS NULL;
            INSERT INTO dbo.tblPasswordResetOtp (UserID, OtpHash, ExpiresAt)
            VALUES (@UserID, @OtpHash, DATEADD(MINUTE, 10, @now));
            SELECT @UserID AS UserID, CAST(SCOPE_IDENTITY() AS int) AS OtpID, 1 AS Status;
        COMMIT;
        RETURN;
    END

    IF @Mode = 2
    BEGIN
        SELECT TOP (1) ID AS OtpID, OtpHash, Attempts
        FROM dbo.tblPasswordResetOtp
        WHERE UserID = @UserID AND ConsumedAt IS NULL AND VerifiedAt IS NULL
          AND ExpiresAt > @now AND Attempts < 5
        ORDER BY ID DESC;
        RETURN;
    END

    IF @Mode = 3
    BEGIN
        UPDATE dbo.tblPasswordResetOtp SET Attempts = Attempts + 1 WHERE ID = @OtpID AND ConsumedAt IS NULL;
        RETURN;
    END

    IF @Mode = 4
    BEGIN
        UPDATE dbo.tblPasswordResetOtp SET VerifiedAt = @now
        WHERE ID = @OtpID AND ConsumedAt IS NULL AND VerifiedAt IS NULL AND ExpiresAt > @now AND Attempts < 5;
        SELECT @@ROWCOUNT AS Verified;
        RETURN;
    END
END
GO

--[uspManageUsers] 4,1
CREATE OR ALTER PROCEDURE [dbo].[uspManageUsers]
@Mode INT,@ID smallint = null,@UserName nvarchar(MAX) = null,@Password nvarchar(MAX) = null,@Mobilenumber nvarchar(MAX) = null,@EMailID nvarchar(MAX) = null,
@RoleID smallint = null,@PwdResetCount tinyint = null,@PwdResetTime datetime = null,@LPin int = null,@Active bit = null,@UserID smallint = null
as
begin
BEGIN TRY
IF(@Mode = 1)
BEGIN
IF((SELECT count(*) FROM tblUsers WHERE UserName = @UserName) > 0)
BEGIN
RAISERROR('User Name already exists',16,1)
END
IF((SELECT count(*) FROM tblUsers WHERE Mobilenumber = @Mobilenumber and isnull(Mobilenumber,'') != '') > 0)
BEGIN
RAISERROR('Mobile No already exists',16,1)
END
IF((SELECT count(*) FROM tblUsers WHERE EMailID = @EMailID and isnull(EMailID,'') != '') > 0)
BEGIN
RAISERROR('EMail ID already exists',16,1)
END
SET @UserName = (select dbo.ProperCase(@UserName))
insert into tblUsers(UserName,Password,Mobilenumber,EMailID,RoleID,Active,CBy,CDate)
Values (@UserName,@Password,@Mobilenumber,lower(@EMailID),ISNULL(@RoleID,0),@Active,@UserID, GETDATE())
SELECT SCOPE_IDENTITY()
END
IF(@Mode = 2)
BEGIN
IF((SELECT count(*) FROM tblUsers WHERE UserName = @UserName and ID != @ID) > 0)
BEGIN
RAISERROR('User Name already exists',16,1)
END
IF((SELECT count(*) FROM tblUsers WHERE Mobilenumber = @Mobilenumber and ID != @ID and isnull(@Mobilenumber,'') != '') > 0)
BEGIN
RAISERROR('Mobile No already exists',16,1)
END
IF((SELECT count(*) FROM tblUsers WHERE EMailID = @EMailID and ID != @ID and isnull(EMailID,'') != '') > 0)
BEGIN
RAISERROR('EMail ID already exists',16,1)
END
-- Security: the password hash is no longer copied into the history table (Column1 = NULL).
INSERT INTO tblMasterHistory (FormID,ID,Name,Column1,Column2,Column3,Column4,Column5,Column6,Column7,Active,CBy,CDate,MBy,MDate,HisCBy,HisCDate)
(select 29,ID, UserName, NULL, Mobilenumber, EMailID, RoleID, PwdResetCount, PwdResetTime, LPin, Active, CBy, CDate, MBy, MDate,
@UserID, GETDATE() from tblUsers where ID = @ID)
SET @UserName = (select dbo.ProperCase(@UserName))
-- NULL @Password = keep the current password (the edit form leaves it blank).
UPDATE tblUsers SET UserName = @UserName,Password = ISNULL(@Password, Password), Mobilenumber = @Mobilenumber,EMailID = lower(@EMailID),
Active = @Active,MBy = @UserID ,MDate = GETDATE(), RoleID = (CASE WHEN @UserID = @ID THEN RoleID ELSE @RoleID END) WHERE ID = @ID

UPDATE tblMobileLogin SET SessionStatus = 0 WHERE UserID = @ID
SELECT @ID
END
IF(@Mode = 3)
BEGIN
-- Security: Password column removed from the result.
SELECT UR.ID,UR.UserName,UR.Mobilenumber,UR.EMailID,UR.RoleID,MR.Name RoleName,UR.PwdResetCount,UR.PwdResetTime,UR.LPin,
UR.CBy,UR.Active,CASE WHEN ISNULL(UR.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END AUserName,
CASE WHEN ISNULL(UR.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),UR.CDate) ELSE CONVERT(NVARCHAR(100),UR.MDate) END LastActionTime,
UR.ImgData
from tblUsers UR
LEFT JOIN tblMasterRole MR ON MR.ID = UR.RoleID
LEFT JOIN tblUsers CUR ON CUR.ID = UR.CBy
LEFT JOIN tblUsers MUR ON MUR.ID = UR.MBy
where UR.ID > 1 order by UR.UserName
END
IF(@Mode = 4)
BEGIN
-- Security: Password column removed from the result (column 1 is still UserName).
SELECT UR.ID,UR.UserName,UR.Mobilenumber,UR.EMailID,UR.RoleID,MR.Name RoleName,UR.PwdResetCount,UR.PwdResetTime,
UR.LPin,UR.CBy,UR.Active,CASE WHEN ISNULL(UR.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END AUserName,
CASE WHEN ISNULL(UR.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),UR.CDate) ELSE CONVERT(NVARCHAR(100),UR.MDate) END LastActionTime,
UR.ImgData
from tblUsers UR
LEFT JOIN tblMasterRole MR ON MR.ID = UR.RoleID
left JOIN tblUsers CUR ON CUR.ID = UR.CBy
LEFT JOIN tblUsers MUR ON MUR.ID = UR.MBy
where UR.ID = @ID --and UR.ID > 1
END
IF(@Mode = 5)
BEGIN
-- Security: only a self-registered account (created by the sign-up page, CBy 0) that was never
-- edited can be activated by the e-mail link; an account an admin disabled stays disabled.
update tblUsers set Active = 1
where ID = @ID and ISNULL(Active,0) = 0 and ISNULL(CBy,0) = 0 and MBy IS NULL
select UserName from tblUsers where ID = @ID
END
IF(@Mode = 6)
BEGIN
SELECT *,(select UpdateClsDate from tblCompanyRegistration where CompanyId = 1) UpdateClsDate,
(select ExpiryDate from tblCompanyRegistration where CompanyId = 1) ExpiryDate ,
(select WebDevices from tblCompanyRegistration where CompanyId = 1) WebDevices
from tblUsers where Active = 1 and UserName = @UserName and Password = @Password
END
IF(@Mode = 7)
BEGIn
if(isnull(@ID,0) = 1)
begin
SELECT * from tblMasterRole order by Name
end
else if(isnull(@ID,0) >= 2)
begin
SELECT * from tblMasterRole WHERE ID > 2 order by Name
end
END
IF(@Mode = 8)
BEGIN
-- Security: only the ID (the API only checks that a row exists). @Password carries the e-mail here.
SELECT ID from tblUsers where UserName = @UserName and EMailID = @Password
END
IF(@Mode = 9)
BEGIN
-- Security: the reset needs an OTP verified on the server (uspPasswordResetOtp mode 4) in the last
-- 15 minutes; the verification is used once.
DECLARE @ResetUserID smallint, @OtpID int
SELECT @ResetUserID = ID from tblUsers where UserName = @UserName and EMailID = @EMailID
SELECT TOP (1) @OtpID = ID FROM dbo.tblPasswordResetOtp
WHERE UserID = @ResetUserID AND VerifiedAt IS NOT NULL AND ConsumedAt IS NULL
  AND VerifiedAt > DATEADD(MINUTE, -15, SYSUTCDATETIME())
ORDER BY ID DESC
IF @OtpID IS NULL OR @Password IS NULL
BEGIN
SELECT 0 AS Updated
END
ELSE
BEGIN
DECLARE @Updated int = 0
BEGIN TRAN
UPDATE dbo.tblPasswordResetOtp SET ConsumedAt = SYSUTCDATETIME() WHERE ID = @OtpID AND ConsumedAt IS NULL
IF @@ROWCOUNT = 1
BEGIN
update tblUsers set Password = @Password where ID = @ResetUserID
SET @Updated = @@ROWCOUNT
UPDATE tblMobileLogin SET SessionStatus = 0 WHERE UserID = @ResetUserID
END
COMMIT
SELECT @Updated AS Updated
END
END
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0 ROLLBACK
SELECT ERROR_MESSAGE() MSG,ERROR_LINE() LINE,ERROR_PROCEDURE() [PROC]
END CATCH
END
GO

-- Remove password values that the old Mode 2 had copied into the history table.
UPDATE dbo.tblMasterHistory SET Column1 = NULL WHERE FormID = 29 AND Column1 IS NOT NULL;
GO
