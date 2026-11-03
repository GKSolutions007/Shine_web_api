/* =====================================================================================
   10_Snapshot_Isolation.sql  -  P2: READ_COMMITTED_SNAPSHOT evaluation (nothing changes by default)
   -------------------------------------------------------------------------------------
   Section 1 is read-only: run it on a live database to see whether readers and writers block
   each other and how big the row-version store would get.
   Sections 2 and 3 change database settings and only run when you set their switch to 1.

   Evaluation done for P2 (details in the P2 report):
   - Blocking today: Query Store lock waits were 0.0 s in 30 days on WSHINE_VIG001 and 3.0 s in
     25 days on WSHINE_TEST01_APR2026. There is no measurable reader/writer blocking to remove.
   - tempdb: load test on a copy of WSHINE_VIG001 with RCSI on: one writer updating ~17,000 rows
     per second (1.56 million row updates in 90 s, thousands of times the real write rate) while
     the product stock report ran in a loop. Peak version store 476 MB in tempdb (tempdb data
     file is 1,160 MB); changed tables grew by the 14-byte row tags (tblFAJournal 13 -> 22 MB).
     Same load with RCSI off: the writer managed 311,000 updates (blocked by the report), the
     report ran 30 times instead of 16. At the real write rate the version store would stay at a
     few MB, so tempdb is not the obstacle.
   - Risk: with RCSI a read no longer waits for an unfinished save; it returns the last committed
     value. 20 procedures read the next document number and write number + 1 afterwards
     (tblYearwiseDocumentSeries / tblMasterUserDefineNoHeader), 9 compute new ids as MAX(...) + 1,
     and stock is checked with a SELECT before it is reduced. Today the second user's read waits
     until the first save commits; under RCSI both read the same value. Reproduced on the copy:
     two simultaneous saves got the SAME document number with RCSI on, distinct numbers with it off.
   Recommendation: keep READ_COMMITTED_SNAPSHOT OFF. If report/save blocking shows up later
   (section 1 shows lock waits), use option 2 (snapshot isolation only for read-only reports),
   which leaves every save exactly as it is today. Enable RCSI (option 3) only after the number
   and stock reads listed above take an update lock (WITH (UPDLOCK, HOLDLOCK)) or use
   UPDATE ... SET @n = DocValue = DocValue + 1.
   ===================================================================================== */
SET NOCOUNT ON;
GO
/* ---------- 1. read-only evaluation ---------- */
SELECT DB_NAME() AS database_name, is_read_committed_snapshot_on, snapshot_isolation_state_desc,
       is_accelerated_database_recovery_on
FROM sys.databases WHERE database_id = DB_ID();

-- lock waits recorded by Query Store (if it is on) - how much time queries spent blocked
IF EXISTS (SELECT 1 FROM sys.database_query_store_options WHERE actual_state_desc <> 'OFF')
    SELECT ws.wait_category_desc,
           CAST(SUM(ws.total_query_wait_time_ms) / 1000.0 AS decimal(12,1)) AS wait_seconds,
           MIN(rsi.start_time) AS since
    FROM sys.query_store_wait_stats ws
    JOIN sys.query_store_runtime_stats_interval rsi ON rsi.runtime_stats_interval_id = ws.runtime_stats_interval_id
    WHERE ws.wait_category_desc IN ('Lock', 'Latch', 'Buffer Latch')
    GROUP BY ws.wait_category_desc;

-- lock waits since the last SQL Server restart (whole instance)
SELECT wait_type, waiting_tasks_count, CAST(wait_time_ms / 1000.0 AS decimal(12,1)) AS wait_seconds,
       (SELECT sqlserver_start_time FROM sys.dm_os_sys_info) AS since
FROM sys.dm_os_wait_stats WHERE wait_type LIKE N'LCK[_]M[_]%' AND waiting_tasks_count > 0
ORDER BY wait_time_ms DESC;

-- row changes since restart (each changed row would create a version under RCSI)
SELECT TOP (15) OBJECT_NAME(s.object_id) AS table_name,
       SUM(s.leaf_insert_count + s.leaf_update_count + s.leaf_delete_count) AS rows_changed
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) s
JOIN sys.objects o ON o.object_id = s.object_id AND o.type = 'U'
WHERE s.index_id IN (0, 1)
GROUP BY s.object_id ORDER BY rows_changed DESC;

-- tempdb size and current version store
SELECT name, type_desc, size * 8 / 1024 AS size_mb, CASE WHEN max_size = -1 THEN NULL ELSE max_size * 8 / 1024 END AS max_mb
FROM tempdb.sys.database_files;
SELECT DB_NAME(database_id) AS database_name, reserved_page_count * 8 / 1024.0 AS version_store_mb
FROM sys.dm_tran_version_store_space_usage;
GO

/* ---------- 2. OPTION (recommended if blocking appears): snapshot isolation for reports only ----------
   ALLOW_SNAPSHOT_ISOLATION ON changes nothing for existing code: only a session that asks for
   SET TRANSACTION ISOLATION LEVEL SNAPSHOT reads row versions. Saves keep their current locking.
   Rows changed afterwards carry 14 extra bytes and changes write versions to tempdb.
   After this, read-only report procedures can start with
       IF @@TRANCOUNT = 0 SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
   (the setting ends with the procedure; never inside a save transaction). */
DECLARE @EnableSnapshotForReports bit = 0;
IF @EnableSnapshotForReports = 1
BEGIN
    DECLARE @sql nvarchar(400) = N'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + N' SET ALLOW_SNAPSHOT_ISOLATION ON;';
    EXEC sys.sp_executesql @sql;
    PRINT N'ALLOW_SNAPSHOT_ISOLATION is ON';
END
GO

/* ---------- 3. OPTION (not recommended yet): READ_COMMITTED_SNAPSHOT ----------
   Changes how EVERY read in EVERY procedure behaves. Do the prerequisites in the header first.
   Needs a moment with no other connections (WITH ROLLBACK IMMEDIATE disconnects them). */
DECLARE @EnableRCSI bit = 0;
IF @EnableRCSI = 1
BEGIN
    DECLARE @sql2 nvarchar(400) = N'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + N' SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;';
    EXEC sys.sp_executesql @sql2;
    PRINT N'READ_COMMITTED_SNAPSHOT is ON. To undo: ALTER DATABASE ... SET READ_COMMITTED_SNAPSHOT OFF WITH ROLLBACK IMMEDIATE;';
END
GO
