/* =====================================================================================
   03_App_Login_Permissions.sql  -  P0: least-privilege access for the web application
   -------------------------------------------------------------------------------------
   Run on each Shine database AFTER 01_Injection_Fixes.sql and 02_Account_Security.sql,
   as sysadmin (or db_owner + securityadmin). Safe to re-run; RE-RUN IT whenever one of the
   signed procedures listed in section 4 is changed (ALTER removes the signature).

   The app should connect as the dedicated login [shineweb_app_login] (member of the role
   [shineweb_app]), not as sa / db_owner. This script gives that role what the API needs and
   nothing more:

   1. EXECUTE on schema dbo         stored procedures, functions and table types
   2. SELECT  on schema dbo         needed because dynamic SQL in report procedures and the
                                    API's inline SELECTs run with the caller's rights
      DENY SELECT on secret columns (password hashes, PINs, tokens, OTPs)
   3. UPDATE  on tblUsers(UserName, Mobilenumber, EMailID, ImgData)   (api/signup/updateuser)
      BACKUP DATABASE                                                 (api/backupfile)
   4. The 4 procedures whose dynamic SQL writes to tables are signed with a certificate.
      The certificate's user (not the app) has write/ALTER rights, and only inside these
      procedures. The private key is removed after signing, so nothing else can be signed.
   5. DENY EXECUTE on uspKillTran and uspShrinkDataBase (server administration, not used by the API).
   6. uspAutoBackUp only calls master.dbo.xp_create_subdir when the caller is allowed to.
      With the least-privilege login, create the folder <BackupPath>\BACKUPFILES\ once and
      give the SQL Server service account write access to it.
   7. OPTIONAL (off by default): remove [mjgk] from db_owner. Set @RemoveMjgkFromDbOwner = 1
      only after the site runs on [shineweb_app_login] and was tested.

   Master sync: uspSyncMasterData reads the source database (appSettings MasterSyncDB) as the
   app login, so run this script on that database too (it needs the SELECT grant there).

   Not done here (server level): the app login itself. If [shineweb_app_login] does not exist,
   the script stops and prints what to do.
   Rollback: section 7 -> ALTER ROLE db_owner ADD MEMBER [mjgk]; the grants/denies can be
   reverted with REVOKE; signatures with DROP SIGNATURE (see section 4).
   ===================================================================================== */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @RemoveMjgkFromDbOwner bit = 0;   -- section 7, see above
DECLARE @sql nvarchar(max);

IF SUSER_ID(N'shineweb_app_login') IS NULL
BEGIN
    RAISERROR(N'Login [shineweb_app_login] does not exist on this server. Create it first (as sysadmin):
    CREATE LOGIN [shineweb_app_login] WITH PASSWORD = N''<new strong password>'', CHECK_POLICY = ON;
then put that password only in the protected Web.config (Deploy\Protect-WebConfig.ps1) and re-run this script.', 16, 1);
    SET NOEXEC ON;   -- skips every following batch of this script
END

IF DATABASE_PRINCIPAL_ID(N'shineweb_app') IS NULL
    CREATE ROLE [shineweb_app];
IF DATABASE_PRINCIPAL_ID(N'shineweb_app_login') IS NULL
    CREATE USER [shineweb_app_login] FOR LOGIN [shineweb_app_login] WITH DEFAULT_SCHEMA = [dbo];
IF IS_ROLEMEMBER(N'shineweb_app', N'shineweb_app_login') = 0
    ALTER ROLE [shineweb_app] ADD MEMBER [shineweb_app_login];

/* ---------- 1-3: role permissions ---------- */
GRANT EXECUTE ON SCHEMA::dbo TO [shineweb_app];
GRANT SELECT  ON SCHEMA::dbo TO [shineweb_app];
GRANT UPDATE ON dbo.tblUsers (UserName, Mobilenumber, EMailID, ImgData) TO [shineweb_app];
GRANT BACKUP DATABASE TO [shineweb_app];

-- Secret columns: stored procedures still read them (ownership chaining is not affected by DENY),
-- but ad-hoc or dynamic SQL running as the app cannot.
DENY SELECT ON dbo.tblUsers (Password, LPin) TO [shineweb_app];
IF OBJECT_ID(N'dbo.tblAppPasswordSettings') IS NOT NULL  DENY SELECT ON dbo.tblAppPasswordSettings (Password) TO [shineweb_app];
IF OBJECT_ID(N'dbo.tblMobileLogin') IS NOT NULL          DENY SELECT ON dbo.tblMobileLogin (TokenValue, ConnectionString) TO [shineweb_app];
IF OBJECT_ID(N'dbo.tblOTPVerification') IS NOT NULL      DENY SELECT ON dbo.tblOTPVerification (OTP) TO [shineweb_app];
IF OBJECT_ID(N'dbo.tblRefreshTokens') IS NOT NULL        DENY SELECT ON dbo.tblRefreshTokens TO [shineweb_app];
IF OBJECT_ID(N'dbo.tblPasswordResetOtp') IS NOT NULL     DENY SELECT ON dbo.tblPasswordResetOtp TO [shineweb_app];

/* ---------- 5: administration procedures ---------- */
IF OBJECT_ID(N'dbo.uspKillTran') IS NOT NULL        DENY EXECUTE ON dbo.uspKillTran TO [shineweb_app];
IF OBJECT_ID(N'dbo.uspShrinkDataBase') IS NOT NULL  DENY EXECUTE ON dbo.uspShrinkDataBase TO [shineweb_app];
GO

/* ---------- 6: uspAutoBackUp without sysadmin ---------- */
IF OBJECT_ID(N'dbo.uspAutoBackUp') IS NOT NULL
    EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE [dbo].[uspAutoBackUp]
@Cond INT=NULL
AS
BEGIN TRY
SET NOCOUNT ON
DECLARE @CompanyCode NVARCHAR(255), @Remainder INT,@LastBackUpDate DATE,@CurrentDate DATE,@AppPath NVARCHAR(MAX) ,@DBName NVARCHAR(255),
@path NVARCHAR(500),@SetBackUpYesNo SMALLINT=0,@FinancialStartDate date
--Get Company code from Table
SELECT @CompanyCode =CompanyCode,@LastBackUpDate=LastBackUpDate ,@AppPath=BackupPath,@FinancialStartDate=F_SD
FROM tblCompanyRegistration

--Login In Time BackUp Database based last back up date
IF ISNULL(@Cond,0) =0
BEGIN
 SELECT @Remainder=ISNULL(AppValue,0) FROM tblAppConfig WHERE AppName =''BackUpRemainder''
 SET @CurrentDate=DATEADD(DAY,@Remainder,@LastBackUpDate)
 IF(@CurrentDate<=CAST(GETDATE() AS DATE))
 BEGIN
  SET @SetBackUpYesNo=1
 END
END
--Dirsct BackUp no Restriction
IF ISNULL(@Cond,0) =1
BEGIN
 SET @SetBackUpYesNo=1
END
--1 For Get Back Up otherwise Not get Back Up.
IF ISNULL(@SetBackUpYesNo,0)=1
 BEGIN
  SET @path=@AppPath+''\BACKUPFILES\'';
  -- xp_create_subdir needs sysadmin. With the least-privilege app login the folder must already exist.
  IF IS_SRVROLEMEMBER(N''sysadmin'') = 1
      EXEC master.dbo.xp_create_subdir @path
  declare @filename nvarchar(255) = ''BK_''+@CompanyCode+''_''+upper (CONVERT(CHAR(3), @FinancialStartDate, 100)) + CONVERT(CHAR(4), @FinancialStartDate, 120)+''_''+REPLACE(CONVERT(NVARCHAR,GETDATE(),112)+''''+CONVERT(NVARCHAR,GETDATE(),114),'':'','''')+''.bak''

  SET @AppPath=@path+@filename

  SET  @DBName=(SELECT DB_NAME())
  BACKUP DATABASE @DBName TO DISK =@AppPath
  UPDATE CR SET LastBackUpDate =GETDATE () FROM tblCompanyRegistration CR WHERE CompanyCode = @CompanyCode
  select @filename as filename,@AppPath as FullPath
 END
END TRY
BEGIN CATCH
SELECT ERROR_MESSAGE() [ERROR_MESSAGE],ERROR_LINE() [ERROR_LINE],ERROR_PROCEDURE() [ERROR_PROCEDURE]
END CATCH';
GO

/* ---------- 4: certificate signing for procedures with dynamic write statements ---------- */
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @procs TABLE (name sysname PRIMARY KEY);
INSERT @procs VALUES (N'uspManageSingleMaster'), (N'uspManageTaxCompGift'), (N'uspUpdateEwayInTrans'), (N'uspSyncMasterData');
DECLARE @sql nvarchar(max), @p sysname;

-- Start clean: drop old signatures, the signer user and the certificate (makes the script re-runnable).
IF CERT_ID(N'ShineDynamicSqlSigner') IS NOT NULL
BEGIN
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT OBJECT_NAME(cp.major_id) FROM sys.crypt_properties cp
        JOIN sys.certificates ce ON ce.thumbprint = cp.thumbprint
        WHERE ce.name = N'ShineDynamicSqlSigner' AND cp.class = 1;
    OPEN c; FETCH NEXT FROM c INTO @p;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'DROP SIGNATURE FROM dbo.' + QUOTENAME(@p) + N' BY CERTIFICATE ShineDynamicSqlSigner;';
        EXEC sys.sp_executesql @sql;
        FETCH NEXT FROM c INTO @p;
    END
    CLOSE c; DEALLOCATE c;
END
IF DATABASE_PRINCIPAL_ID(N'ShineDynamicSqlSigner') IS NOT NULL DROP USER ShineDynamicSqlSigner;
IF CERT_ID(N'ShineDynamicSqlSigner') IS NOT NULL DROP CERTIFICATE ShineDynamicSqlSigner;

-- One-time random password: only used while signing, the private key is removed afterwards.
DECLARE @pwd nvarchar(128) = CONVERT(nvarchar(128), CRYPT_GEN_RANDOM(32), 2) + N'aA1!';
SET @sql = N'CREATE CERTIFICATE ShineDynamicSqlSigner ENCRYPTION BY PASSWORD = ' + QUOTENAME(@pwd, N'''')
         + N' WITH SUBJECT = N''Signs Shine procedures whose dynamic SQL writes to tables'', EXPIRY_DATE = ''2099-12-31'';';
EXEC sys.sp_executesql @sql;
CREATE USER ShineDynamicSqlSigner FROM CERTIFICATE ShineDynamicSqlSigner;
-- ALTER is needed for SET IDENTITY_INSERT in uspSyncMasterData.
GRANT SELECT, INSERT, UPDATE, DELETE, ALTER ON SCHEMA::dbo TO ShineDynamicSqlSigner;

DECLARE c2 CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM @procs WHERE OBJECT_ID(N'dbo.' + QUOTENAME(name)) IS NOT NULL;
OPEN c2; FETCH NEXT FROM c2 INTO @p;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ADD SIGNATURE TO dbo.' + QUOTENAME(@p) + N' BY CERTIFICATE ShineDynamicSqlSigner WITH PASSWORD = ' + QUOTENAME(@pwd, N'''') + N';';
    EXEC sys.sp_executesql @sql;
    PRINT N'signed dbo.' + @p;
    FETCH NEXT FROM c2 INTO @p;
END
CLOSE c2; DEALLOCATE c2;
ALTER CERTIFICATE ShineDynamicSqlSigner REMOVE PRIVATE KEY;
GO

/* ---------- 7: optional - take db_owner away from mjgk ---------- */
SET NOCOUNT ON;
DECLARE @RemoveMjgkFromDbOwner bit = 0;   -- set to 1 only after the site runs on shineweb_app_login
IF @RemoveMjgkFromDbOwner = 1 AND IS_ROLEMEMBER(N'db_owner', N'mjgk') = 1
BEGIN
    ALTER ROLE db_owner DROP MEMBER [mjgk];
    PRINT N'mjgk removed from db_owner (still a member of shineweb_app).';
END

/* ---------- report ---------- */
SELECT r.name AS role_name, m.name AS member_name
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name IN (N'db_owner', N'shineweb_app')
ORDER BY r.name, m.name;
GO
SET NOEXEC OFF;
GO
