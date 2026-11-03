<#
.SYNOPSIS
    Saves a performance baseline from Query Store (P3), and compares two baselines.

.DESCRIPTION
    Capture: writes CSV files for one database into  <OutDir>\<Database>_<yyyyMMdd_HHmm>\
      by_procedure.csv   time per stored procedure / function (all its statements added up)
      by_query.csv       top statements by total CPU, duration, reads and executions (query_hash)
      waits.csv          wait categories (Lock, CPU, Buffer IO, ...)
      info.txt           database, Query Store state, period covered, server version
    Only reads Query Store and catalog views; nothing in the database changes.

    Compare: reads two capture folders and writes compare_by_procedure.csv next to the newer one:
    executions and average CPU / duration / reads per call, before and after, with the change in %.
    Use average-per-call numbers: the two periods rarely have the same number of calls.

    The CSVs contain statement text (the first 300 characters). Keep the output folder out of any
    public repository (default OutDir is outside the repository; .gitignore also excludes Baselines\).

.EXAMPLE
    # before deploying P1 (on the production server, same account that runs the other scripts)
    .\Capture-PerfBaseline.ps1 -Server . -Database WSHINE_VIG001 -Days 30
    # a few weeks after deploying
    .\Capture-PerfBaseline.ps1 -Server . -Database WSHINE_VIG001 -Days 14 `
        -CompareWith 'D:\ShineBaselines\WSHINE_VIG001_20261104_0300'
#>
[CmdletBinding()]
param(
    [string] $Server = '.',
    [Parameter(Mandatory = $true)] [string] $Database,
    [int] $Days = 30,
    [int] $Top = 50,
    [string] $OutDir = 'D:\ShineBaselines',
    [string] $CompareWith
)
$ErrorActionPreference = 'Stop'
$b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$b['Data Source'] = $Server; $b['Initial Catalog'] = $Database; $b['Integrated Security'] = $true
$b['TrustServerCertificate'] = $true; $b['Application Name'] = 'Capture-PerfBaseline'; $b['ApplicationIntent'] = 'ReadOnly'
$cs = $b.ConnectionString

function Query([string] $sql) {
    $cn = New-Object System.Data.SqlClient.SqlConnection $cs
    try {
        $cn.Open(); $c = $cn.CreateCommand(); $c.CommandTimeout = 600; $c.CommandText = $sql
        [void]$c.Parameters.AddWithValue('@days', $Days); [void]$c.Parameters.AddWithValue('@top', $Top)
        $t = New-Object System.Data.DataTable; $t.Load($c.ExecuteReader()); return ,$t
    } finally { $cn.Dispose() }
}

$state = Query "SELECT actual_state_desc, current_storage_size_mb, max_storage_size_mb, stale_query_threshold_days FROM sys.database_query_store_options"
if ($state.Rows.Count -eq 0 -or $state.Rows[0].actual_state_desc -eq 'OFF') {
    throw "Query Store is OFF on $Database. Turn it on (ALTER DATABASE ... SET QUERY_STORE = ON) and capture after a few days of normal use."
}

# runtime stats of the period, per plan, weighted by executions
$stats = @"
WITH rs AS (
    SELECT p.query_id, SUM(r.count_executions) AS execs,
           SUM(r.avg_cpu_time * r.count_executions) / 1000.0 AS cpu_ms,
           SUM(r.avg_duration * r.count_executions) / 1000.0 AS dur_ms,
           SUM(r.avg_logical_io_reads * r.count_executions) AS reads,
           MAX(r.max_duration) / 1000.0 AS max_dur_ms,
           MIN(r.first_execution_time) AS first_seen, MAX(r.last_execution_time) AS last_seen
    FROM sys.query_store_runtime_stats r
    JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id = r.runtime_stats_interval_id
    JOIN sys.query_store_plan p ON p.plan_id = r.plan_id
    WHERE i.start_time >= DATEADD(DAY, -@days, SYSUTCDATETIME())
    GROUP BY p.query_id)
"@

$byProc = Query ($stats + @"
SELECT n.object_name,
       COUNT(DISTINCT q.query_id) AS statements, SUM(rs.execs) AS statement_executions,
       CAST(SUM(rs.cpu_ms) AS decimal(18,1)) AS total_cpu_ms, CAST(SUM(rs.dur_ms) AS decimal(18,1)) AS total_duration_ms,
       CAST(SUM(rs.reads) AS bigint) AS total_reads, CAST(MAX(rs.max_dur_ms) AS decimal(18,1)) AS max_statement_ms,
       -- calls of the procedure itself are not stored by Query Store; the busiest statement is a good proxy
       MAX(rs.execs) AS approx_calls,
       CAST(SUM(rs.cpu_ms) / NULLIF(MAX(rs.execs), 0) AS decimal(18,3)) AS cpu_ms_per_call,
       CAST(SUM(rs.dur_ms) / NULLIF(MAX(rs.execs), 0) AS decimal(18,3)) AS duration_ms_per_call,
       CAST(SUM(rs.reads) / NULLIF(MAX(rs.execs), 0) AS decimal(18,1)) AS reads_per_call
FROM rs JOIN sys.query_store_query q ON q.query_id = rs.query_id
CROSS APPLY (SELECT CASE WHEN q.object_id = 0 THEN N'(ad hoc / dynamic SQL)'
                         ELSE ISNULL(OBJECT_SCHEMA_NAME(q.object_id) + N'.' + OBJECT_NAME(q.object_id), N'(object no longer exists)') END AS object_name) n
GROUP BY n.object_name
ORDER BY total_cpu_ms DESC;
"@)

$byQuery = Query ($stats + @"
, agg AS (
    SELECT q.query_hash, MIN(q.object_id) AS object_id, SUM(rs.execs) AS execs, SUM(rs.cpu_ms) AS cpu_ms, SUM(rs.dur_ms) AS dur_ms,
           SUM(rs.reads) AS reads, MAX(rs.max_dur_ms) AS max_dur_ms, MIN(rs.first_seen) AS first_seen, MAX(rs.last_seen) AS last_seen,
           MIN(q.query_text_id) AS query_text_id
    FROM rs JOIN sys.query_store_query q ON q.query_id = rs.query_id
    GROUP BY q.query_hash),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY cpu_ms DESC) AS r_cpu, ROW_NUMBER() OVER (ORDER BY dur_ms DESC) AS r_dur,
              ROW_NUMBER() OVER (ORDER BY reads DESC) AS r_reads, ROW_NUMBER() OVER (ORDER BY execs DESC) AS r_execs
    FROM agg)
SELECT CONVERT(varchar(20), r.query_hash, 1) AS query_hash,
       CASE WHEN r.object_id = 0 THEN N'(ad hoc / dynamic SQL)'
            ELSE ISNULL(OBJECT_SCHEMA_NAME(r.object_id) + N'.' + OBJECT_NAME(r.object_id), N'(object no longer exists)') END AS object_name,
       r.execs, CAST(r.cpu_ms AS decimal(18,1)) AS total_cpu_ms, CAST(r.dur_ms AS decimal(18,1)) AS total_duration_ms,
       CAST(r.reads AS bigint) AS total_reads,
       CAST(r.cpu_ms / NULLIF(r.execs, 0) AS decimal(18,3)) AS cpu_ms_per_exec,
       CAST(r.dur_ms / NULLIF(r.execs, 0) AS decimal(18,3)) AS duration_ms_per_exec,
       CAST(r.reads / NULLIF(r.execs, 0) AS decimal(18,1)) AS reads_per_exec,
       CAST(r.max_dur_ms AS decimal(18,1)) AS max_duration_ms, r.first_seen, r.last_seen,
       r.r_cpu AS rank_cpu, r.r_dur AS rank_duration, r.r_reads AS rank_reads, r.r_execs AS rank_executions,
       LEFT(REPLACE(REPLACE(REPLACE(t.query_sql_text, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '), 300) AS statement_start
FROM ranked r JOIN sys.query_store_query_text t ON t.query_text_id = r.query_text_id
WHERE r.r_cpu <= @top OR r.r_dur <= @top OR r.r_reads <= @top OR r.r_execs <= @top
ORDER BY r.cpu_ms DESC;
"@)

$waits = Query @"
SELECT ws.wait_category_desc, CAST(SUM(ws.total_query_wait_time_ms) / 1000.0 AS decimal(18,1)) AS wait_seconds
FROM sys.query_store_wait_stats ws
JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id = ws.runtime_stats_interval_id
WHERE i.start_time >= DATEADD(DAY, -@days, SYSUTCDATETIME())
GROUP BY ws.wait_category_desc ORDER BY wait_seconds DESC;
"@
$period = Query @"
SELECT MIN(i.start_time) AS from_utc, MAX(i.end_time) AS to_utc
FROM sys.query_store_runtime_stats_interval i WHERE i.start_time >= DATEADD(DAY, -@days, SYSUTCDATETIME());
"@
$ver = Query "SELECT @@SERVERNAME AS server_name, CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)) AS version, CAST(SERVERPROPERTY('Edition') AS nvarchar(100)) AS edition"

$folder = Join-Path $OutDir ("{0}_{1}" -f $Database, (Get-Date -Format 'yyyyMMdd_HHmm'))
New-Item -ItemType Directory -Force $folder | Out-Null
$byProc  | Export-Csv (Join-Path $folder 'by_procedure.csv') -NoTypeInformation -Encoding UTF8
$byQuery | Export-Csv (Join-Path $folder 'by_query.csv') -NoTypeInformation -Encoding UTF8
$waits   | Export-Csv (Join-Path $folder 'waits.csv') -NoTypeInformation -Encoding UTF8
@(
    "database:        $Database",
    "server:          $($ver.Rows[0].server_name)  ($($ver.Rows[0].edition), $($ver.Rows[0].version))",
    "captured:        $(Get-Date -Format 'yyyy-MM-dd HH:mm') local",
    "period (UTC):    $($period.Rows[0].from_utc)  ->  $($period.Rows[0].to_utc)   (last $Days days requested)",
    "query store:     $($state.Rows[0].actual_state_desc), $($state.Rows[0].current_storage_size_mb) of $($state.Rows[0].max_storage_size_mb) MB, keeps $($state.Rows[0].stale_query_threshold_days) days",
    "procedures:      $($byProc.Rows.Count) objects with activity; top statements kept: $($byQuery.Rows.Count)",
    "total CPU:       $([math]::Round((($byProc.Rows | Measure-Object total_cpu_ms -Sum).Sum) / 1000, 1)) s",
    "total duration:  $([math]::Round((($byProc.Rows | Measure-Object total_duration_ms -Sum).Sum) / 1000, 1)) s"
) | Set-Content (Join-Path $folder 'info.txt') -Encoding UTF8
Write-Host "Baseline written to $folder"

if ($CompareWith) {
    $old = @{}; Import-Csv (Join-Path $CompareWith 'by_procedure.csv') | ForEach-Object { $old[$_.object_name] = $_ }
    $new = Import-Csv (Join-Path $folder 'by_procedure.csv')
    function Pct($a, $b) { if ([double]$a -eq 0) { return '' }; return [math]::Round(([double]$b - [double]$a) / [double]$a * 100, 1) }
    $rows = foreach ($n in $new) {
        $o = $old[$n.object_name]
        [pscustomobject]@{
            object_name = $n.object_name
            calls_before = if ($o) { $o.approx_calls } else { '' }; calls_after = $n.approx_calls
            cpu_ms_per_call_before = if ($o) { $o.cpu_ms_per_call } else { '' }; cpu_ms_per_call_after = $n.cpu_ms_per_call
            cpu_change_pct = if ($o) { Pct $o.cpu_ms_per_call $n.cpu_ms_per_call } else { 'new' }
            duration_ms_per_call_before = if ($o) { $o.duration_ms_per_call } else { '' }; duration_ms_per_call_after = $n.duration_ms_per_call
            duration_change_pct = if ($o) { Pct $o.duration_ms_per_call $n.duration_ms_per_call } else { 'new' }
            reads_per_call_before = if ($o) { $o.reads_per_call } else { '' }; reads_per_call_after = $n.reads_per_call
            reads_change_pct = if ($o) { Pct $o.reads_per_call $n.reads_per_call } else { 'new' }
            total_cpu_ms_after = $n.total_cpu_ms
        }
    }
    $rows | Sort-Object { [double]$_.total_cpu_ms_after } -Descending | Export-Csv (Join-Path $folder 'compare_by_procedure.csv') -NoTypeInformation -Encoding UTF8
    Write-Host "Comparison with $CompareWith written to $(Join-Path $folder 'compare_by_procedure.csv')"
}
