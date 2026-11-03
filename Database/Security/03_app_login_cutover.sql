/* =====================================================================================
   03  Move the Shine web app to a least-privilege SQL login (point 6) - CUTOVER

   This file changes server security. Read each step, replace the <PLACEHOLDERS>, and run
   one step at a time in SSMS as a sysadmin. Steps 3 and 6 are commented out on purpose.

   Order:  01 (procedures)  ->  02 (role)  ->  this file.
   Do it on the test database first, run through the app, then repeat for production.
   ===================================================================================== */

/* -------------------------------------------------------------------------------------
   STEP 1 (read-only): which login does the app use today, and what can it do?
   Open the web app in a browser first so it has live connections.
   ------------------------------------------------------------------------------------- */
SELECT DISTINCT s.login_name, s.host_name, s.program_name, DB_NAME(s.database_id) AS database_name
FROM sys.dm_exec_sessions s
WHERE s.is_user_process = 1 AND s.program_name LIKE N'%.Net SqlClient%';

-- Server roles of every SQL/Windows login (look for sysadmin on the app login)
SELECT l.name AS login_name, r.name AS server_role
FROM sys.server_role_members rm
JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.server_principals l ON l.principal_id = rm.member_principal_id
ORDER BY l.name;

-- Database roles in this database (look for db_owner on the app user)
SELECT u.name AS db_user, r.name AS db_role
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals u ON u.principal_id = rm.member_principal_id
ORDER BY u.name;
GO

/* -------------------------------------------------------------------------------------
   STEP 2: create the new login and map it to the role from 02.
   Replace <STRONG_PASSWORD> (long, random; store it in your password manager, not here)
   and the database names if yours differ. NEVER save this file with the real password in it:
   it is in source control. Easier: create the login with any temporary password, then let
   Deploy\Rotate-Secrets.ps1 -RotateSqlPassword generate the real one and update Web.config.
   ------------------------------------------------------------------------------------- */
USE [master];
GO
IF SUSER_ID(N'shineweb_app_login') IS NULL
    CREATE LOGIN [shineweb_app_login]
        WITH PASSWORD = N'<STRONG_PASSWORD>',
             CHECK_POLICY = ON,
             DEFAULT_DATABASE = [WSHINE_TEST01_APR2026];
GO
USE [WSHINE_TEST01_APR2026];-- CREATE ROLE
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'shineweb_app'
      AND type = 'R'
)
BEGIN
    CREATE ROLE [shineweb_app];
    PRINT 'Role shineweb_app created successfully.';
END
ELSE
BEGIN
    PRINT 'Role shineweb_app already exists.';
END;
GO

USE [WSHINE_TEST01_APR2026];
GO
IF DATABASE_PRINCIPAL_ID(N'shineweb_app_login') IS NULL
    CREATE USER [shineweb_app_login] FOR LOGIN [shineweb_app_login] WITH DEFAULT_SCHEMA = [dbo];
ALTER ROLE [shineweb_app] ADD MEMBER [shineweb_app_login];
GO

/* -------------------------------------------------------------------------------------
   STEP 3: other databases the API connects to.
   a) Master sync reads from the database in Web.config appSettings "MasterSyncDB"
      (currently WSHINE_DEV001_APR2024). Read-only access is enough.
   b) The "ShinecodeConnection" connection string points at a second database. Give the new
      login the same treatment there (create the shineweb_app role with 02's core grants),
      or keep that connection on its current login until it is reviewed separately.
   ------------------------------------------------------------------------------------- */
-- USE [WSHINE_DEV001_APR2024];
-- GO
-- IF DATABASE_PRINCIPAL_ID(N'shineweb_app_login') IS NULL
--     CREATE USER [shineweb_app_login] FOR LOGIN [shineweb_app_login];
-- ALTER ROLE [db_datareader] ADD MEMBER [shineweb_app_login];
-- GO

/* -------------------------------------------------------------------------------------
   STEP 4: point the API at the new login.
   - Build the new connection string with User ID=shineweb_app_login and the new password.
   - Encrypt it the same way as today (clsEncryptDecrypt.Encrypt) and replace the
     "Connections" value in SampWebApi\Web.config (and the UI's Web.config if it connects
     directly). Recycle the IIS app pool.
   - Keep the old encrypted value aside so you can switch back in seconds.
   ------------------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------------------
   STEP 5: test with the new login before removing anything.
   Log in, open each list page and filter (Party with an apostrophe too), save one document
   of each type, run master sync, run a backup, run the product opening import, print a report.
   Any "permission was denied" error names the object: grant only that, to [shineweb_app].
   You can also test from SSMS directly:
   ------------------------------------------------------------------------------------- */
-- EXECUTE AS LOGIN = N'shineweb_app_login';
--     EXEC dbo.uspFilterCollectionPayment @Mode = N'1', @DocPrefix = 19, @Name = N'D''Souza Traders',
--          @FromDate = '2026-04-01', @ToDate = '2026-10-31', @ShowAllStatus = 0;
--     SELECT * FROM fn_my_permissions(NULL, 'DATABASE');
-- REVERT;

/* -------------------------------------------------------------------------------------
   STEP 6: only after STEP 5 passes - remove the high rights from the OLD app login.
   Replace <OLD_APP_LOGIN> with the name found in STEP 1. Do NOT run this if the old login
   is the one you (or other tools / SQL Agent jobs) use to administer the server.
   ------------------------------------------------------------------------------------- */
-- USE [WSHINE_TEST01_APR2026];
-- ALTER ROLE [db_owner] DROP MEMBER [<OLD_APP_LOGIN>];
-- USE [master];
-- ALTER SERVER ROLE [sysadmin] DROP MEMBER [<OLD_APP_LOGIN>];
-- -- or, if nothing else uses it:  ALTER LOGIN [<OLD_APP_LOGIN>] DISABLE;

/* -------------------------------------------------------------------------------------
   ROLLBACK
   - Put the old encrypted connection string back in Web.config and recycle the app pool.
   - Then, if you want to remove the new login completely:
   ------------------------------------------------------------------------------------- */
-- USE [WSHINE_TEST01_APR2026];
-- ALTER ROLE [shineweb_app] DROP MEMBER [shineweb_app_login];
-- DROP USER [shineweb_app_login];
-- USE [master];
-- DROP LOGIN [shineweb_app_login];
