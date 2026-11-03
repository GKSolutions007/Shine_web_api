<#
.SYNOPSIS
    Full / differential / transaction-log backups for the Shine databases, with checks and clean-up (P3).

.DESCRIPTION
    SQL Server Express has no SQL Agent, so this script is meant to be run by Windows Task Scheduler
    (see Register-BackupTasks.ps1). For each database it:
      - Full / Diff : BACKUP DATABASE ... WITH CHECKSUM to <BackupDir>\<db>\<db>_FULL|DIFF_<time>.bak
      - Log         : BACKUP LOG ... WITH CHECKSUM to <BackupDir>\<db>\<db>_LOG_<time>.trn
                      (only for databases in FULL recovery; if there is no full backup yet since the
                      switch to FULL, a full backup is taken first, because the log chain starts there)
      - -Verify     : RESTORE VERIFYONLY ... WITH CHECKSUM on the file just written
      - clean-up    : deletes files older than -KeepDays, but never the newest full backup or the
                      differential/log files that belong after it
    It writes one line per action to <BackupDir>\backup.log and exits with code 1 if anything failed,
    so Task Scheduler shows the run as failed.

    The account that runs it needs, in each database, membership of db_backupoperator (or more), and
    write access to <BackupDir> (it writes backup.log and creates one folder per database); the SQL
    Server service account (e.g. NT Service\MSSQLSERVER) needs write access to <BackupDir> as well. Keep <BackupDir> on a different
    disk than the database files, and copy it off the server (another machine / cloud): a backup on
    the same disk does not survive a disk failure.

    The application's own "backup" button (uspAutoBackUp) keeps working; its full backups do not
    break the log chain.

.EXAMPLE
    .\Backup-ShineDatabase.ps1 -Database WSHINE_VIG001 -Type Full -BackupDir 'E:\SqlBackup' -Verify
    .\Backup-ShineDatabase.ps1 -Database WSHINE_VIG001,WSHINE_TEST01_APR2026 -Type Log -BackupDir 'E:\SqlBackup'
#>
[CmdletBinding()]
param(
    [string] $Server = '.',
    [Parameter(Mandatory = $true)] [string[]] $Database,
    [Parameter(Mandatory = $true)] [ValidateSet('Full', 'Diff', 'Log')] [string] $Type,
    [Parameter(Mandatory = $true)] [string] $BackupDir,
    [int] $KeepDays = 14,
    [switch] $Verify
)
$ErrorActionPreference = 'Stop'
# "A,B" arrives as one string when started with powershell.exe -File (Task Scheduler): split it
$Database = @($Database | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim(" '`"") } | Where-Object { $_ })
$failed = $false
$logFile = Join-Path $BackupDir 'backup.log'
New-Item -ItemType Directory -Force $BackupDir | Out-Null
function Log([string] $msg) {
    $line = "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $msg
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}
function Exec([string] $db, [string] $sql, [hashtable] $p = @{}) {
    $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $b['Data Source'] = $Server; $b['Initial Catalog'] = 'master'; $b['Integrated Security'] = $true
    $b['TrustServerCertificate'] = $true; $b['Application Name'] = 'Backup-ShineDatabase'
    $cn = New-Object System.Data.SqlClient.SqlConnection $b.ConnectionString
    try {
        $cn.Open(); $c = $cn.CreateCommand(); $c.CommandTimeout = 0; $c.CommandText = $sql
        foreach ($k in $p.Keys) { [void]$c.Parameters.AddWithValue($k, $p[$k]) }
        $t = New-Object System.Data.DataTable; $t.Load($c.ExecuteReader()); return ,$t
    } finally { $cn.Dispose() }
}

foreach ($db in $Database) {
    try {
        $info = Exec $db @"
SELECT d.recovery_model_desc, d.state_desc,
       (SELECT MAX(b.backup_finish_date) FROM msdb.dbo.backupset b WHERE b.database_name = d.name AND b.type = 'D' AND b.is_copy_only = 0) AS last_full,
       -- a full backup taken after the log chain was broken / started counts (last_log_backup_lsn is NULL when no chain)
       drs.last_log_backup_lsn
FROM sys.databases d JOIN sys.database_recovery_status drs ON drs.database_id = d.database_id
WHERE d.name = @db
"@ @{ '@db' = $db }
        if ($info.Rows.Count -eq 0) { throw "database not found" }
        $r = $info.Rows[0]
        if ($r.state_desc -ne 'ONLINE') { throw "database is $($r.state_desc)" }
        $kind = $Type
        if ($Type -eq 'Log') {
            if ($r.recovery_model_desc -eq 'SIMPLE') { Log "$db  LOG skipped: recovery model is SIMPLE (no point-in-time restore; see 12_Recovery_Model.sql)"; continue }
            if ($r.last_log_backup_lsn -is [DBNull]) { Log "$db  no log chain yet (no full backup since FULL recovery was set): taking a full backup first"; $kind = 'Full' }
        }
        if ($Type -eq 'Diff' -and $r.last_full -is [DBNull]) { Log "$db  no full backup yet: taking a full backup instead of a differential"; $kind = 'Full' }

        $dir = Join-Path $BackupDir $db
        New-Item -ItemType Directory -Force $dir | Out-Null
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $ext = if ($kind -eq 'Log') { 'trn' } else { 'bak' }
        $file = Join-Path $dir ("{0}_{1}_{2}.{3}" -f $db, $kind.ToUpper(), $stamp, $ext)
        $sql = switch ($kind) {
            'Full' { "BACKUP DATABASE " + "[$($db.Replace(']', ']]'))]" + " TO DISK = @f WITH CHECKSUM, INIT, NAME = @n;" }
            'Diff' { "BACKUP DATABASE " + "[$($db.Replace(']', ']]'))]" + " TO DISK = @f WITH DIFFERENTIAL, CHECKSUM, INIT, NAME = @n;" }
            'Log'  { "BACKUP LOG " + "[$($db.Replace(']', ']]'))]" + " TO DISK = @f WITH CHECKSUM, INIT, NAME = @n;" }
        }
        $t0 = Get-Date
        [void](Exec $db $sql @{ '@f' = $file; '@n' = "$db $kind $stamp" })
        $size = if (Test-Path $file) { [math]::Round((Get-Item $file).Length / 1MB, 1) } else { '?' }
        Log ("{0}  {1} backup OK  {2}  ({3} MB, {4:n0} s)" -f $db, $kind.ToUpper(), $file, $size, ((Get-Date) - $t0).TotalSeconds)
        if ($Verify) {
            [void](Exec $db "RESTORE VERIFYONLY FROM DISK = @f WITH CHECKSUM;" @{ '@f' = $file })
            Log "$db  verify OK  $file"
        }

        # clean-up: keep everything from the newest full backup on, delete older files past KeepDays
        $files = Get-ChildItem $dir -File | Where-Object { $_.Name -match '_(FULL|DIFF|LOG)_\d{8}_\d{6}\.(bak|trn)$' } | Sort-Object Name
        $newestFull = $files | Where-Object Name -match '_FULL_' | Sort-Object LastWriteTime | Select-Object -Last 1
        if ($newestFull) {
            $limit = (Get-Date).AddDays(-$KeepDays)
            foreach ($f in $files) {
                if ($f.LastWriteTime -lt $limit -and $f.LastWriteTime -lt $newestFull.LastWriteTime) {
                    try { Remove-Item $f.FullName -Force; Log "$db  deleted old backup $($f.Name)" }
                    catch { Log "$db  WARNING could not delete $($f.Name): $($_.Exception.Message)" }
                }
            }
        }
    } catch {
        $failed = $true
        Log "$db  $Type backup FAILED: $($_.Exception.Message -replace '\s+', ' ')"
    }
}
if ($failed) { exit 1 }
