<#
.SYNOPSIS
    Registers Windows scheduled tasks that run Backup-ShineDatabase.ps1 (P3). SQL Server Express has
    no SQL Agent, so Task Scheduler does the scheduling.

.DESCRIPTION
    Creates (or replaces) three tasks under \Shine\ :
      Shine DB full backup   daily at -FullAt (default 01:00), with RESTORE VERIFYONLY
      Shine DB diff backup   daily at -DiffAt (default 13:00)
      Shine DB log backup    every -LogEveryMinutes (default 15) - only does something for databases
                             in FULL recovery (12_Recovery_Model.sql)
    Every 15 minutes means at most 15 minutes of work can be lost; choose the interval with the business.

    -RunAs: the Windows account the tasks run as. It needs a SQL login with db_backupoperator in each
    database (this script does not change SQL permissions or server roles). Default is SYSTEM, which
    only works if NT AUTHORITY\SYSTEM has such a login.
    Run from an elevated PowerShell. Use -WhatIf to see what would be registered.

.EXAMPLE
    .\Register-BackupTasks.ps1 -Database WSHINE_VIG001,WSHINE_TEST01_APR2026 -BackupDir 'E:\SqlBackup' -WhatIf
    .\Register-BackupTasks.ps1 -Database WSHINE_VIG001 -BackupDir 'E:\SqlBackup' -RunAs 'DOMAIN\svc-sqlbackup'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $Server = '.',
    [Parameter(Mandatory = $true)] [string[]] $Database,
    [Parameter(Mandatory = $true)] [string] $BackupDir,
    [string] $FullAt = '01:00',
    [string] $DiffAt = '13:00',
    [int] $LogEveryMinutes = 15,
    [int] $KeepDays = 14,
    [string] $RunAs = 'SYSTEM'
)
$ErrorActionPreference = 'Stop'
$script = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Backup-ShineDatabase.ps1'
if (-not (Test-Path $script)) { throw "Backup-ShineDatabase.ps1 not found next to this script." }
if ($Database | Where-Object { $_ -match '[,\s"'']' }) { throw 'Database names with commas, spaces or quotes are not supported here.' }
$dbList = $Database -join ','

function ArgsFor([string] $type, [bool] $verify) {
    $a = "-NoProfile -ExecutionPolicy Bypass -File `"$script`" -Server `"$Server`" -Database $dbList -Type $type -BackupDir `"$BackupDir`" -KeepDays $KeepDays"
    if ($verify) { $a += ' -Verify' }
    return $a
}
$tasks = @(
    @{ Name = 'Shine DB full backup'; Args = (ArgsFor 'Full' $true);  Trigger = (New-ScheduledTaskTrigger -Daily -At $FullAt) },
    @{ Name = 'Shine DB diff backup'; Args = (ArgsFor 'Diff' $false); Trigger = (New-ScheduledTaskTrigger -Daily -At $DiffAt) },
    @{ Name = 'Shine DB log backup';  Args = (ArgsFor 'Log' $false);
       Trigger = (New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes $LogEveryMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)) }
)
$principal = if ($RunAs -eq 'SYSTEM') { New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest }
             else { $null }
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 6)
$cred = $null
if ($RunAs -ne 'SYSTEM' -and -not $WhatIfPreference) { $cred = Get-Credential -UserName $RunAs -Message "Password for $RunAs (stored by Task Scheduler)" }

foreach ($t in $tasks) {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $t.Args
    if ($PSCmdlet.ShouldProcess("\Shine\$($t.Name)", "register: powershell.exe $($t.Args)")) {
        if ($principal) {
            Register-ScheduledTask -TaskPath '\Shine\' -TaskName $t.Name -Action $action -Trigger $t.Trigger -Principal $principal -Settings $settings -Force | Out-Null
        } else {
            Register-ScheduledTask -TaskPath '\Shine\' -TaskName $t.Name -Action $action -Trigger $t.Trigger -Settings $settings `
                -User $cred.UserName -Password $cred.GetNetworkCredential().Password -RunLevel Highest -Force | Out-Null
        }
        Write-Host "registered \Shine\$($t.Name)"
    }
}
