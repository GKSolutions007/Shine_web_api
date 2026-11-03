/* =====================================================================================
   02  ROLLBACK - removes the [shineweb_app] role and restores the original uspAutoBackUp.
   Run 03's rollback first if an app login was already added to the role.
   ===================================================================================== */
SET NOCOUNT ON;
GO

IF DATABASE_PRINCIPAL_ID(N'shineweb_app') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.database_role_members rm
               WHERE rm.role_principal_id = DATABASE_PRINCIPAL_ID(N'shineweb_app'))
        THROW 50001, N'shineweb_app still has members. Remove them first (see 03_app_login_cutover.sql, ROLLBACK section).', 1;

    REVOKE BACKUP DATABASE FROM [shineweb_app];
    DECLARE @sql nvarchar(max) = N'';
    SELECT @sql += N'REVOKE ' + pe.permission_name + N' ON ' +
        CASE pe.class WHEN 3 THEN N'SCHEMA::' + QUOTENAME(SCHEMA_NAME(pe.major_id))
                      WHEN 1 THEN N'OBJECT::' + QUOTENAME(OBJECT_SCHEMA_NAME(pe.major_id)) + N'.' + QUOTENAME(OBJECT_NAME(pe.major_id))
                      WHEN 6 THEN N'TYPE::' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name) END +
        N' FROM [shineweb_app];' + CHAR(10)
    FROM sys.database_permissions pe
    LEFT JOIN sys.types t ON pe.class = 6 AND t.user_type_id = pe.major_id
    WHERE pe.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'shineweb_app') AND pe.class IN (1,3,6);
    EXEC sys.sp_executesql @sql;
    DROP ROLE [shineweb_app];
END
GO

/****** uspAutoBackUp (original) ******/
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
  EXEC master.dbo.xp_create_subdir @path
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
