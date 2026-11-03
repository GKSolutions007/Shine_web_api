<#
.SYNOPSIS
    Converts every remaining legacy (reversibly encrypted) password to a PBKDF2 hash (P1, item 4).

.DESCRIPTION
    tblUsers.Password and tblAppPasswordSettings.Password used to hold clsEncryptDecrypt
    ciphertext. Its key is in the source code, so anyone with the code and a database copy could
    read every password. The API already upgrades a user's value when that user logs in; this
    script upgrades all the others now, so the legacy fallback can be switched off.

    It loads the API's own SampWebApi.dll, so decryption and hashing are exactly the code the site
    uses. A value is converted only when re-encrypting the decrypted text gives back the stored
    value (so unknown formats are left alone and reported). Updates are conditional on the old
    value (no lost update if a user logs in at the same moment). No secret is printed.

    After it reports "remaining legacy: 0" on EVERY database the site uses, set
        <add key="AllowLegacyPasswords" value="false" />
    in the API Web.config appSettings.

.EXAMPLE
    .\Migrate-LegacyPasswords.ps1 -Database WSHINE_TEST01_APR2026 -DryRun
    .\Migrate-LegacyPasswords.ps1 -Server . -Database WSHINE_TEST01_APR2026
#>
[CmdletBinding()]
param(
    [string] $Server = '.',
    [Parameter(Mandatory = $true)] [string] $Database,
    [string] $ApiBin,
    [string] $ConnectionString,
    [switch] $DryRun
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Data
# $PSScriptRoot is not available in param() defaults on Windows PowerShell 5.1, so resolve it here
if (-not $ApiBin) { $ApiBin = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\SampWebApi\bin' }
$dll = Join-Path (Resolve-Path $ApiBin) 'SampWebApi.dll'
if (-not (Test-Path $dll)) { throw "SampWebApi.dll not found in $ApiBin (build the API first or pass -ApiBin)." }
[void][Reflection.Assembly]::LoadFrom($dll)
$hasher = [SampWebApi.Utility.PasswordHasher]
$enc = [SampWebApi.DALHelper.clsEncryptDecrypt]

if (-not $ConnectionString) {
    $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $b['Data Source'] = $Server; $b['Initial Catalog'] = $Database; $b['Integrated Security'] = $true
    $b['TrustServerCertificate'] = $true; $b['Application Name'] = 'Migrate-LegacyPasswords'
    $ConnectionString = $b.ConnectionString
}
$cn = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
$cn.Open()

function Convert-Legacy([string] $stored) {
    # returns the new hash, or $null when the value is not a recognisable legacy value
    try { $plain = $enc::Decrypt($stored) } catch { return $null }
    if ([string]::IsNullOrEmpty($plain)) { return $null }
    if ($enc::Encrypt($plain) -cne $stored) { return $null }
    $hash = $hasher::Hash($plain)
    $needs = $false
    if (-not $hasher::Verify($plain, $hash, [ref]$needs)) { return $null }
    return $hash
}

function Migrate([string] $label, [string] $selectSql, [scriptblock] $update) {
    $cmd = $cn.CreateCommand(); $cmd.CommandText = $selectSql
    $rows = New-Object System.Collections.Generic.List[object]
    $r = $cmd.ExecuteReader()
    while ($r.Read()) { $rows.Add([pscustomobject]@{ Id = $r.GetValue(0); Stored = $r.GetString(1) }) }
    $r.Close()
    $done = 0; $skipped = 0; $lost = 0
    foreach ($row in $rows) {
        $new = Convert-Legacy $row.Stored
        if ($null -eq $new) { $skipped++; Write-Warning "$label id $($row.Id): not a recognisable legacy value, left unchanged."; continue }
        if ($DryRun) { $done++; continue }
        if (& $update $row.Id $row.Stored $new) { $done++ } else { $lost++ }
    }
    $verb = if ($DryRun) { 'would convert' } else { 'converted' }
    Write-Host ("{0}: legacy values found {1}, {2} {3}, skipped {4}, changed meanwhile {5}" -f $label, $rows.Count, $verb, $done, $skipped, $lost)
}

Migrate 'tblUsers' "SELECT ID, Password FROM dbo.tblUsers WHERE Password IS NOT NULL AND Password <> N'' AND Password NOT LIKE N'PBKDF2$%'" {
    param($id, $old, $new)
    $c = $cn.CreateCommand(); $c.CommandType = 'StoredProcedure'; $c.CommandText = 'dbo.uspSetUserPasswordHash'
    [void]$c.Parameters.AddWithValue('@ID', [int16]$id); [void]$c.Parameters.AddWithValue('@OldPassword', $old); [void]$c.Parameters.AddWithValue('@NewPassword', $new)
    return ([int]$c.ExecuteScalar() -eq 1)
}

$probe = $cn.CreateCommand(); $probe.CommandText = "SELECT CASE WHEN OBJECT_ID(N'dbo.tblAppPasswordSettings', N'U') IS NULL THEN 0 ELSE 1 END"
if ([int]$probe.ExecuteScalar() -eq 1) {
    Migrate 'tblAppPasswordSettings' "SELECT PwdID, Password FROM dbo.tblAppPasswordSettings WHERE Password IS NOT NULL AND Password <> N'' AND Password NOT LIKE N'PBKDF2$%'" {
        param($id, $old, $new)
        $c = $cn.CreateCommand()
        $c.CommandText = 'UPDATE dbo.tblAppPasswordSettings SET Password = @new WHERE PwdID = @id AND Password = @old'
        [void]$c.Parameters.AddWithValue('@id', [int]$id); [void]$c.Parameters.AddWithValue('@old', $old); [void]$c.Parameters.AddWithValue('@new', $new)
        return ($c.ExecuteNonQuery() -eq 1)
    }
}

$c = $cn.CreateCommand()
$c.CommandText = "DECLARE @n int = (SELECT COUNT(*) FROM dbo.tblUsers WHERE Password IS NOT NULL AND Password <> N'' AND Password NOT LIKE N'PBKDF2$%'); IF OBJECT_ID(N'dbo.tblAppPasswordSettings', N'U') IS NOT NULL EXEC sp_executesql N'SELECT @n += COUNT(*) FROM dbo.tblAppPasswordSettings WHERE Password IS NOT NULL AND Password <> N'''' AND Password NOT LIKE N''PBKDF2$%''', N'@n int OUTPUT', @n OUTPUT; SELECT @n;"
$left = [int]$c.ExecuteScalar()
$cn.Close()
Write-Host "remaining legacy: $left$(if ($DryRun) { ' (dry run: nothing written)' })"
if (-not $DryRun -and $left -eq 0) { Write-Host 'This database is fully migrated. Once every database is, set appSettings AllowLegacyPasswords=false in the API Web.config.' }
