<#
.SYNOPSIS
    Rotates the Shine web secrets on a server (point 5): JWT signing key, SMTP app password and the
    SQL login password used by the connection strings.

.DESCRIPTION
    Every secret that was ever committed to source control (or stored with clsEncryptDecrypt, whose
    key is in the source) must be treated as known to anyone with the code. Removing it from the
    repository is not enough: the old value stays in git history. The fix is a new value that has
    never been in the repository.

    Run this ON THE WEB SERVER, in an elevated PowerShell, AFTER Deploy\Protect-WebConfig.ps1 has
    converted the site(s). It refuses to run on a config that is not protected, because writing a
    new secret as clsEncryptDecrypt ciphertext would make it readable again straight away.

    The <connectionStrings> and <appSettings> sections are opened through the .NET configuration
    API, changed in memory and saved encrypted again with their existing provider, so new values
    are never written to disk unencrypted. Nothing secret is printed.

      -RotateJwtKey        New random 512-bit key -> API appSettings JwtSecretKey.
                           Every signed-in user is signed out (old tokens stop validating).
      -RotateSmtpPassword  New SMTP password -> API appSettings passkey. Create a new Gmail app
                           password for the account in appSettings "email" FIRST, then revoke the
                           old one in the Google account after this script succeeds.
                           Pass -NewSmtpPassword, or the script prompts (input hidden).
      -RotateSqlPassword   ALTER LOGIN with a new random 32-character password (or -NewSqlPassword),
                           verifies it, then updates every connection string in the API and UI
                           configs that uses that login on that server. If anything fails after
                           the ALTER LOGIN, the old password is put back and the configs restored.
                           Refuses sysadmin logins unless -AllowPrivilegedLogin: rotate the
                           dedicated web login from Database\Security\03 instead of sa.

    Saving Web.config restarts the site (IIS recycles the app domain). Between the ALTER LOGIN and
    the save, new database connections from the site fail for a few seconds: use a quiet moment.

    UNDO
      Each run backs up Web.config to Web.config.bak-<timestamp> (still encrypted with the
      server's key). Copy it back to undo a config change; for the SQL password also run
      ALTER LOGIN with the old password. Delete the backups once the site is confirmed working.

.EXAMPLE
    .\Rotate-Secrets.ps1 -ApiSitePath "D:\Host\NewWebShineAPI" -UiSitePath "D:\Host\NewWebShine" -RotateJwtKey -RotateSmtpPassword -RotateSqlPassword -DryRun
    .\Rotate-Secrets.ps1 -ApiSitePath "D:\Host\NewWebShineAPI" -UiSitePath "D:\Host\NewWebShine" -RotateJwtKey -RotateSmtpPassword -RotateSqlPassword
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $ApiSitePath,
    [string] $UiSitePath,
    [switch] $RotateJwtKey,
    [switch] $RotateSmtpPassword,
    [switch] $RotateSqlPassword,
    [securestring] $NewSmtpPassword,
    [securestring] $NewSqlPassword,
    [string] $SqlLogin,
    [string] $SqlAdminConnectionString,
    [switch] $AllowPrivilegedLogin,
    [switch] $DryRun
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Configuration
Add-Type -AssemblyName System.Data

if (-not ($RotateJwtKey -or $RotateSmtpPassword -or $RotateSqlPassword)) {
    throw 'Choose at least one of -RotateJwtKey, -RotateSmtpPassword, -RotateSqlPassword.'
}

function Get-Plain([securestring] $s) {
    $p = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($p) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p) }
}

function New-RandomBytes([int] $count) {
    $b = New-Object byte[] $count
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($b) } finally { $rng.Dispose() }
    return $b
}

# 32 characters with upper, lower, digit and symbol; no characters that need quoting in a
# connection string or in T-SQL (; = ' " { } [ ] and space).
function New-SqlPassword {
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!#%*+-_.:?@^~')
    $all = -join $sets
    do {
        $bytes = New-RandomBytes 64
        $chars = for ($i = 0; $i -lt 32; $i++) { $all[$bytes[$i] % $all.Length] }
        $candidate = -join $chars
        $ok = $true
        foreach ($s in $sets) { if (-not ($candidate.ToCharArray() | Where-Object { $s.Contains([string]$_) })) { $ok = $false } }
    } while (-not $ok)
    return $candidate
}

function Open-SiteConfig([string] $sitePath, [string] $label) {
    $file = Join-Path $sitePath 'Web.config'
    if (-not (Test-Path -LiteralPath $file)) { throw "$label : Web.config not found in $sitePath" }
    [xml] $raw = Get-Content -Raw -LiteralPath $file
    foreach ($section in 'connectionStrings', 'appSettings') {
        $node = $raw.configuration.$section
        if (-not $node -or -not $node.EncryptedData) {
            throw "$label : <$section> is not encrypted. Run Deploy\Protect-WebConfig.ps1 on this site first."
        }
    }
    $map = New-Object System.Configuration.ExeConfigurationFileMap
    $map.ExeConfigFilename = $file
    $cfg = [System.Configuration.ConfigurationManager]::OpenMappedExeConfiguration($map, [System.Configuration.ConfigurationUserLevel]::None)
    $flag = $cfg.AppSettings.Settings['SecretsArePlainText']
    if (-not $flag -or $flag.Value -ne 'true') {
        throw "$label : SecretsArePlainText is not true. Run Deploy\Protect-WebConfig.ps1 on this site first."
    }
    return [pscustomobject]@{ Label = $label; File = $file; Config = $cfg; Changed = $false }
}

function Save-SiteConfig($site) {
    foreach ($s in $site.Config.ConnectionStrings, $site.Config.AppSettings) {
        if (-not $s.SectionInformation.IsProtected) { throw "$($site.Label): a section lost its protection; not saving." }
        $s.SectionInformation.ForceSave = $true
    }
    $site.Config.Save([System.Configuration.ConfigurationSaveMode]::Modified)
    [xml] $check = Get-Content -Raw -LiteralPath $site.File
    if (-not $check.configuration.connectionStrings.EncryptedData -or -not $check.configuration.appSettings.EncryptedData) {
        throw "$($site.Label): sections are not encrypted after saving."
    }
}

function Invoke-AlterLogin([string] $adminCs, [string] $login, [string] $password) {
    $cn = New-Object System.Data.SqlClient.SqlConnection $adminCs
    try {
        $cn.Open()
        $cmd = $cn.CreateCommand()
        $cmd.CommandText = @"
DECLARE @sql nvarchar(max) = N'ALTER LOGIN ' + QUOTENAME(@login) + N' WITH PASSWORD = ' + QUOTENAME(@pwd, N'''') + N';';
IF @sql IS NULL THROW 50001, N'Login name or password too long.', 1;
EXEC sys.sp_executesql @sql;
"@
        [void]$cmd.Parameters.Add('@login', [Data.SqlDbType]::NVarChar, 128)
        [void]$cmd.Parameters.Add('@pwd', [Data.SqlDbType]::NVarChar, 128)
        $cmd.Parameters['@login'].Value = $login
        $cmd.Parameters['@pwd'].Value = $password
        [void]$cmd.ExecuteNonQuery()
    } finally { $cn.Dispose() }
}

function Test-SqlLogin([string] $cs) {
    $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $cs
    $b.psbase.Pooling = $false
    $cn = New-Object System.Data.SqlClient.SqlConnection $b.psbase.ConnectionString
    try { $cn.Open() } finally { $cn.Dispose() }
}

# ---------------------------------------------------------------- open configs
$sites = New-Object System.Collections.Generic.List[object]
$api = Open-SiteConfig $ApiSitePath 'Api'
$sites.Add($api)
if ($UiSitePath) { $sites.Add((Open-SiteConfig $UiSitePath 'Ui')) }
$plan = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------- JWT key
if ($RotateJwtKey) {
    $setting = $api.Config.AppSettings.Settings['JwtSecretKey']
    if (-not $setting) { throw 'Api: appSettings JwtSecretKey not found.' }
    $newKey = [Convert]::ToBase64String((New-RandomBytes 64))
    if ($newKey -eq $setting.Value) { throw 'Generated key equals the current key.' }
    $setting.Value = $newKey
    $api.Changed = $true
    $plan.Add('Api  appSettings/JwtSecretKey : new random 512-bit key (all users will be signed out)')
}

# ---------------------------------------------------------------- SMTP password
if ($RotateSmtpPassword) {
    $setting = $api.Config.AppSettings.Settings['passkey']
    if (-not $setting) { throw 'Api: appSettings passkey not found.' }
    if (-not $NewSmtpPassword) {
        if ($DryRun) { $NewSmtpPassword = ConvertTo-SecureString 'dry-run-placeholder' -AsPlainText -Force }
        else {
            $a = Read-Host 'New SMTP app password' -AsSecureString
            $b = Read-Host 'Repeat it' -AsSecureString
            if ((Get-Plain $a) -ne (Get-Plain $b)) { throw 'The two SMTP passwords do not match.' }
            $NewSmtpPassword = $a
        }
    }
    # Gmail shows app passwords in groups of four; the spaces are not part of the password.
    $smtp = (Get-Plain $NewSmtpPassword) -replace '\s', ''
    if ($smtp.Length -lt 8) { throw 'The new SMTP password is shorter than 8 characters.' }
    if ($smtp -eq $setting.Value) { throw 'The new SMTP password is the same as the current one.' }
    $setting.Value = $smtp
    $api.Changed = $true
    $user = $api.Config.AppSettings.Settings['email']
    $plan.Add("Api  appSettings/passkey : new SMTP password for $(if ($user) { $user.Value } else { '(appSettings email missing)' })")
    foreach ($s in $sites) {
        if ($s.Label -ne 'Api' -and $s.Config.AppSettings.Settings['passkey']) {
            $plan.Add("$($s.Label)   appSettings/passkey : present but NOT changed (this site's code still decrypts it with clsEncryptDecrypt)")
        }
    }
}

# ---------------------------------------------------------------- SQL login password
$sqlTargets = New-Object System.Collections.Generic.List[object]
$oldSqlPassword = $null; $newSqlPlain = $null; $adminCs = $null; $loginName = $null
if ($RotateSqlPassword) {
    $main = $api.Config.ConnectionStrings.ConnectionStrings['Connections']
    if (-not $main) { throw 'Api: connection string "Connections" not found.' }
    $mb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $main.ConnectionString
    if ($mb.psbase.IntegratedSecurity) { throw 'Api "Connections" uses Windows authentication: there is no SQL password to rotate.' }
    $loginName = if ($SqlLogin) { $SqlLogin } else { $mb.psbase.UserID }
    if (-not $loginName) { throw 'Could not find the SQL login (no User ID in "Connections"); pass -SqlLogin.' }
    $server = $mb.psbase.DataSource.Trim().ToLowerInvariant()

    foreach ($s in $sites) {
        foreach ($c in $s.Config.ConnectionStrings.ConnectionStrings) {
            # skip entries inherited from machine.config (e.g. LocalSqlServer)
            $src = $c.ElementInformation.Source
            if ([string]::IsNullOrEmpty($c.ConnectionString) -or -not $src -or
                [IO.Path]::GetFullPath($src) -ne [IO.Path]::GetFullPath($s.File)) { continue }
            try { $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $c.ConnectionString } catch { continue }
            if (-not $b.psbase.IntegratedSecurity -and $b.psbase.DataSource.Trim().ToLowerInvariant() -eq $server -and $b.psbase.UserID -ieq $loginName) {
                if ($null -eq $oldSqlPassword) { $oldSqlPassword = $b.psbase.Password }
                elseif ($b.psbase.Password -ne $oldSqlPassword) { throw "$($s.Label) $($c.Name): uses $loginName with a different password than Api Connections. Fix that first." }
                $sqlTargets.Add([pscustomobject]@{ Site = $s; Entry = $c; Builder = $b })
            }
        }
    }
    if ($sqlTargets.Count -eq 0) { throw "No connection string uses login $loginName on $($mb.psbase.DataSource)." }

    if ($SqlAdminConnectionString) { $adminCs = $SqlAdminConnectionString }
    else {
        $ab = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
        $ab.psbase.DataSource = $mb.psbase.DataSource; $ab.psbase.InitialCatalog = 'master'; $ab.psbase.IntegratedSecurity = $true
        $ab.psbase.Encrypt = $mb.psbase.Encrypt; $ab.psbase.TrustServerCertificate = $mb.psbase.TrustServerCertificate; $ab.psbase.Pooling = $false
        $adminCs = $ab.psbase.ConnectionString
    }

    $newSqlPlain = if ($NewSqlPassword) { Get-Plain $NewSqlPassword } else { New-SqlPassword }
    if ($newSqlPlain -eq $oldSqlPassword) { throw 'The new SQL password is the same as the current one.' }
    foreach ($t in $sqlTargets) {
        $t.Builder.psbase.Password = $newSqlPlain
        $t.Entry.ConnectionString = $t.Builder.psbase.ConnectionString
        $t.Site.Changed = $true
        $plan.Add("$($t.Site.Label)$(' ' * (5 - $t.Site.Label.Length))connectionStrings/$($t.Entry.Name) : new password for login $loginName")
    }
    $plan.Add("SQL  ALTER LOGIN [$loginName] on $($mb.psbase.DataSource) (connects as the Windows user running this script unless -SqlAdminConnectionString)")
}

Write-Host 'Planned changes (no secret values are shown):'
$plan | ForEach-Object { Write-Host "  - $_" }

if ($RotateSqlPassword) {
    # read-only checks, also in a dry run
    $cn = New-Object System.Data.SqlClient.SqlConnection $adminCs
    try {
        $cn.Open()
        $cmd = $cn.CreateCommand()
        $cmd.CommandText = "SELECT SUSER_ID(@l), IS_SRVROLEMEMBER(N'sysadmin', @l), IS_SRVROLEMEMBER(N'sysadmin'), IS_SRVROLEMEMBER(N'securityadmin');"
        [void]$cmd.Parameters.AddWithValue('@l', $loginName)
        $r = $cmd.ExecuteReader(); [void]$r.Read()
        $exists = -not $r.IsDBNull(0); $privileged = (-not $r.IsDBNull(1)) -and $r.GetInt32(1) -eq 1
        $canAlter = ((-not $r.IsDBNull(2)) -and $r.GetInt32(2) -eq 1) -or ((-not $r.IsDBNull(3)) -and $r.GetInt32(3) -eq 1)
        $r.Close()
    } finally { $cn.Dispose() }
    if (-not $exists) { throw "SQL login $loginName does not exist on the server." }
    if ($privileged -and -not $AllowPrivilegedLogin) {
        throw "SQL login $loginName is sysadmin. Rotating it breaks every other tool that uses it. Move the site to the dedicated login (Database\Security\03) and rotate that, or pass -AllowPrivilegedLogin."
    }
    if (-not $canAlter) { throw 'The admin connection is not sysadmin/securityadmin, so it cannot change the password.' }
    Write-Host "  - SQL checks passed: login exists, not sysadmin$(if ($privileged) { ' (overridden)' }), admin connection can change it"
}

if ($DryRun) { Write-Host 'Dry run: nothing written.'; return }

# ---------------------------------------------------------------- apply
$stamp = Get-Date -Format yyyyMMddHHmmss
$backups = @{}
foreach ($s in $sites | Where-Object { $_.Changed }) {
    $bak = "$($s.File).bak-$stamp"
    Copy-Item -LiteralPath $s.File -Destination $bak
    $backups[$s.File] = $bak
    Write-Host "Backup: $bak"
}

$loginChanged = $false
try {
    if ($RotateSqlPassword) {
        Invoke-AlterLogin $adminCs $loginName $newSqlPlain
        $loginChanged = $true
        Test-SqlLogin $sqlTargets[0].Entry.ConnectionString
        Write-Host "SQL login $loginName : password changed and verified."
    }
    foreach ($s in $sites | Where-Object { $_.Changed }) {
        Save-SiteConfig $s
        Write-Host "$($s.Label): Web.config saved, sections still encrypted."
    }
}
catch {
    $err = $_.Exception.Message
    foreach ($f in $backups.Keys) { Copy-Item -LiteralPath $backups[$f] -Destination $f -Force }
    if ($loginChanged) {
        try { Invoke-AlterLogin $adminCs $loginName $oldSqlPassword; Write-Warning "SQL login $loginName put back to its previous password." }
        catch { Write-Warning "Could NOT put the SQL password back: $($_.Exception.Message). The configs were restored, so the site cannot connect until ALTER LOGIN is fixed by hand." }
    }
    throw "Failed, Web.config restored from backup: $err"
}

Write-Host ''
Write-Host 'Done. Next:'
Write-Host '  1. Browse the site(s) and sign in (everyone else must sign in again if the JWT key changed).'
if ($RotateSmtpPassword) { Write-Host '  2. Send a test mail (forgot-password), then revoke the OLD app password in the Google account.' }
if ($RotateSqlPassword)  { Write-Host '  3. Update any other client that uses this SQL login (it now has a new password).' }
Write-Host "  4. Delete the backups (*.bak-$stamp) once everything works."
