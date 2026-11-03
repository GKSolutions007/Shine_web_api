/* =====================================================================================
   12_Recovery_Model.sql  -  P3: FULL recovery for point-in-time restore (off by default)
   -------------------------------------------------------------------------------------
   Business decision first: how much work may be lost (RPO) and how long a restore may take (RTO)?
   - SIMPLE recovery (today): you can only go back to the last full backup. Everything typed in
     since then (invoices, collections, stock) is lost if the database file is lost or damaged.
   - FULL recovery + log backups every N minutes: restore to any moment, at most N minutes lost,
     and restore to "just before" a mistake (e.g. a wrong bulk update) is possible.
     Cost: log backup files (small for this workload) and a scheduled job that must keep running:
     WITHOUT log backups the log file grows until the disk is full.

   Run on one database at a time (in its context). Steps when the business says yes:
     1. Register the backup tasks first:  Deploy\Register-BackupTasks.ps1 (log task included).
     2. Set @SwitchToFull = 1 below and run this script.
     3. Immediately take a full backup:   Deploy\Backup-ShineDatabase.ps1 -Type Full -Verify
        (the log chain starts with this backup; the log task also does it if you forget).
     4. Test a restore to a point in time on another server/copy, once (example at the bottom).
   Section 1 is read-only and can be run any time to see the current state.
   ===================================================================================== */
SET NOCOUNT ON;
GO
/* ---------- 1. current state (read-only) ---------- */
SELECT d.name, d.recovery_model_desc, d.log_reuse_wait_desc,
       CAST(ls.total_log_size_in_bytes / 1048576.0 AS decimal(12,1)) AS log_size_mb,
       CAST(ls.used_log_space_in_percent AS decimal(5,1)) AS log_used_pct,
       (SELECT MAX(backup_finish_date) FROM msdb.dbo.backupset WHERE database_name = d.name AND type = 'D' AND is_copy_only = 0) AS last_full,
       (SELECT MAX(backup_finish_date) FROM msdb.dbo.backupset WHERE database_name = d.name AND type = 'I') AS last_diff,
       (SELECT MAX(backup_finish_date) FROM msdb.dbo.backupset WHERE database_name = d.name AND type = 'L') AS last_log,
       CASE WHEN drs.last_log_backup_lsn IS NULL THEN 'no log chain (SIMPLE, or FULL without a full backup yet)' ELSE 'log chain active' END AS log_chain
FROM sys.databases d
JOIN sys.database_recovery_status drs ON drs.database_id = d.database_id
CROSS JOIN sys.dm_db_log_space_usage ls   -- current database
WHERE d.database_id = DB_ID();

-- where backups went during the last 30 days (the app's own backups from uspAutoBackUp appear here too)
SELECT TOP (20) b.backup_finish_date, CASE b.type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFF' WHEN 'L' THEN 'LOG' ELSE b.type END AS kind,
       b.is_copy_only, CAST(b.backup_size / 1048576.0 AS decimal(12,1)) AS size_mb, mf.physical_device_name
FROM msdb.dbo.backupset b JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = b.media_set_id
WHERE b.database_name = DB_NAME() AND b.backup_finish_date >= DATEADD(DAY, -30, GETDATE())
ORDER BY b.backup_finish_date DESC;
GO

/* ---------- 2. switch to FULL ---------- */
DECLARE @SwitchToFull bit = 0;
IF @SwitchToFull = 1
BEGIN
    IF (SELECT recovery_model_desc FROM sys.databases WHERE database_id = DB_ID()) = 'FULL'
        PRINT DB_NAME() + N' is already in FULL recovery.';
    ELSE
    BEGIN
        DECLARE @sql nvarchar(400) = N'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + N' SET RECOVERY FULL;';
        EXEC sys.sp_executesql @sql;
        PRINT DB_NAME() + N' is now in FULL recovery. Take a full backup NOW (Backup-ShineDatabase.ps1 -Type Full -Verify) and make sure the log backup task runs.';
    END
END
GO

/* ---------- 3. undo: back to SIMPLE (stops point-in-time restore; the log can be reused again) ---------- */
DECLARE @BackToSimple bit = 0;
IF @BackToSimple = 1
BEGIN
    DECLARE @sql2 nvarchar(400) = N'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + N' SET RECOVERY SIMPLE;';
    EXEC sys.sp_executesql @sql2;
    PRINT DB_NAME() + N' is back in SIMPLE recovery. Disable the log backup task.';
END
GO

/* ---------- restore to a point in time (example, run on a test server) ----------
RESTORE DATABASE [WSHINE_RESTORE_TEST] FROM DISK = N'E:\SqlBackup\WSHINE_VIG001\WSHINE_VIG001_FULL_20261110_010000.bak'
    WITH NORECOVERY, MOVE N'<data logical name>' TO N'...\WSHINE_RESTORE_TEST.mdf', MOVE N'<log logical name>' TO N'...\WSHINE_RESTORE_TEST.ldf';
-- optional: the newest DIFF before the target time, WITH NORECOVERY
RESTORE LOG [WSHINE_RESTORE_TEST] FROM DISK = N'...\WSHINE_VIG001_LOG_20261110_101500.trn' WITH NORECOVERY;
RESTORE LOG [WSHINE_RESTORE_TEST] FROM DISK = N'...\WSHINE_VIG001_LOG_20261110_103000.trn' WITH STOPAT = '2026-11-10 10:22:00', RECOVERY;
------------------------------------------------------------------------------------------- */
