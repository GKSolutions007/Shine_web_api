/* =====================================================================================
   02  Least-privilege database role for the Shine web app (point 6)

   WHAT THIS DOES
     Creates the database role [shineweb_app] with only the rights the app actually uses:
       - EXECUTE on all procedures/functions/table types in dbo
       - SELECT / INSERT / UPDATE / DELETE on dbo tables. These are needed because 86
         procedures build dynamic SQL (dynamic SQL runs with the caller's rights, so ownership
         chaining does not apply), and the API runs a few inline queries (e.g. UPDATE tblUsers
         in LoginController, SELECT from tblAppConfig / tblCompanyRegistration / tblMasterProduct).
       - VIEW DEFINITION on dbo: SqlCommandBuilder.DeriveParameters (every API call) and
         sp_helptext in uspReportScript.
       - Narrow extras: BACKUP DATABASE (uspAutoBackUp), ALTER on tblClosingStock
         (TRUNCATE in uspManageProductOpeingImport), ALTER on the tables enabled for master
         sync (IDENTITY_INSERT in uspSyncMasterData).
     Not granted: db_owner, DDL (CREATE/ALTER/DROP of objects), CONTROL, server-level rights,
     xp_cmdshell, login/user management, other databases.
     It also updates uspAutoBackUp so a missing sysadmin right for xp_create_subdir does not
     abort the backup (see the note on that procedure).

   SAFE TO RUN ANY TIME
     Nobody is a member of the role yet, so nothing changes for the running app until the
     cutover in 03_app_login_cutover.sql. Re-runnable.

   RUN AS: a db_owner of the target database (e.g. WSHINE_TEST01_APR2026). Run 01 first.
   UNDO:   02_rollback_app_role.sql
   ===================================================================================== */
SET NOCOUNT ON;
GO

IF DATABASE_PRINCIPAL_ID(N'shineweb_app') IS NULL
    CREATE ROLE [shineweb_app] AUTHORIZATION [dbo];
GO

-- Core rights
GRANT EXECUTE         ON SCHEMA::[dbo] TO [shineweb_app];
GRANT SELECT          ON SCHEMA::[dbo] TO [shineweb_app];
GRANT INSERT          ON SCHEMA::[dbo] TO [shineweb_app];
GRANT UPDATE          ON SCHEMA::[dbo] TO [shineweb_app];
GRANT DELETE          ON SCHEMA::[dbo] TO [shineweb_app];
GRANT VIEW DEFINITION ON SCHEMA::[dbo] TO [shineweb_app];
GO

-- Table types used as TVP parameters (covered by the schema grant; explicit for clarity).
DECLARE @t sysname, @sql nvarchar(400);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.table_types WHERE schema_id = SCHEMA_ID(N'dbo');
OPEN c; FETCH NEXT FROM c INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'GRANT EXECUTE ON TYPE::[dbo].' + QUOTENAME(@t) + N' TO [shineweb_app];';
    EXEC sys.sp_executesql @sql;
    FETCH NEXT FROM c INTO @t;
END
CLOSE c; DEALLOCATE c;
GO

-- uspAutoBackUp (api/backupfile): BACKUP DATABASE
GRANT BACKUP DATABASE TO [shineweb_app];
GO

-- uspManageProductOpeingImport: TRUNCATE TABLE tblClosingStock needs ALTER on that table
IF OBJECT_ID(N'dbo.tblClosingStock', N'U') IS NOT NULL
    GRANT ALTER ON OBJECT::[dbo].[tblClosingStock] TO [shineweb_app];
GO

-- uspSyncMasterData: SET IDENTITY_INSERT needs ALTER on each synced table.
-- Only the tables enabled in tblWebshineMasterSyncTables (the same list 01 now enforces).
-- Re-run this block if you enable more tables for sync later.
DECLARE @t sysname, @sql nvarchar(400);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT TableName FROM dbo.tblWebshineMasterSyncTables
    WHERE IsSync = 1 AND OBJECT_ID(N'dbo.' + QUOTENAME(TableName), N'U') IS NOT NULL;
OPEN c; FETCH NEXT FROM c INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'GRANT ALTER ON OBJECT::[dbo].' + QUOTENAME(@t) + N' TO [shineweb_app];';
    EXEC sys.sp_executesql @sql;
    PRINT N'Granted ALTER (master sync) on dbo.' + @t;
    FETCH NEXT FROM c INTO @t;
END
CLOSE c; DEALLOCATE c;
GO

/****** uspAutoBackUp ******/
-- Change: xp_create_subdir (in master) needs sysadmin, which the app login will no longer have.
-- The call is now wrapped in TRY/CATCH so the backup continues; the <BackupPath>\BACKUPFILES
-- folder must already exist on the SQL Server machine (create it once). Everything else is unchanged.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[uspAutoBackUp]
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
 SELECT @Remainder=ISNULL(AppValue,0) FROM tblAppConfig WHERE AppName ='BackUpRemainder'
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
  SET @path=@AppPath+'\BACKUPFILES\';
  -- Needs sysadmin; under the least-privilege login the folder must already exist.
  BEGIN TRY
   EXEC master.dbo.xp_create_subdir @path
  END TRY
  BEGIN CATCH
  END CATCH
  declare @filename nvarchar(255) = 'BK_'+@CompanyCode+'_'+upper (CONVERT(CHAR(3), @FinancialStartDate, 100)) + CONVERT(CHAR(4), @FinancialStartDate, 120)+'_'+REPLACE(CONVERT(NVARCHAR,GETDATE(),112)+''+CONVERT(NVARCHAR,GETDATE(),114),':','')+'.bak'


  SET @AppPath=@path+@filename

  SET  @DBName=(SELECT DB_NAME())
  BACKUP DATABASE @DBName TO DISK =@AppPath
  UPDATE CR SET LastBackUpDate =GETDATE () FROM tblCompanyRegistration CR WHERE CompanyCode = @CompanyCode
  select @filename as filename,@AppPath as FullPath
 END
END TRY
BEGIN CATCH
SELECT ERROR_MESSAGE() [ERROR_MESSAGE],ERROR_LINE() [ERROR_LINE],ERROR_PROCEDURE() [ERROR_PROCEDURE]
END CATCH
GO

/* Procedures that will NOT work under the new login, on purpose (admin-only; nothing in the
   app calls them): uspShrinkDataBase (DBCC SHRINKFILE / FREEPROCCACHE) and uspKillTran (KILL).
   Run them from SSMS as an administrator if ever needed. */

-- Review what the role can do:
SELECT pr.name AS principal, pe.class_desc, pe.permission_name, pe.state_desc,
       COALESCE(SCHEMA_NAME(pe.major_id), OBJECT_NAME(pe.major_id), TYPE_NAME(pe.major_id)) AS securable
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name = N'shineweb_app'
ORDER BY pe.class_desc, securable, pe.permission_name;
GO
