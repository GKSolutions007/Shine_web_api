<#
.SYNOPSIS
    Moves a deployed Web.config from the legacy "encrypted with a key in source" secrets to ASP.NET
    protected configuration (point 9).

.DESCRIPTION
    Today connection strings, the JWT signing key and the SMTP passkey are stored as
    clsEncryptDecrypt ciphertext. That AES key is hard-coded in the source, so anyone with the code
    and the config file can read them. This script, run ON THE WEB SERVER for one deployed site:

      1. Backs up Web.config (Web.config.bak-<timestamp>).
      2. Decrypts the legacy values using the site's own bin\<app>.dll (so the key is not copied
         anywhere else) and writes them back as plain text:
           - every <connectionStrings> entry that is legacy ciphertext
           - Api only: appSettings JwtSecretKey and passkey
         Other appSettings (e.g. the UI's apiurl / GAPIs) are left as they are; the code still
         decrypts those itself.
      3. Sets appSettings SecretsArePlainText = true (read by SecretConfig in the new build).
      4. Immediately encrypts the <connectionStrings> and <appSettings> sections with
         aspnet_regiis (-pef, DataProtectionConfigurationProvider = machine-bound DPAPI).
         ASP.NET decrypts them transparently at run time.
      5. Verifies both sections are encrypted; on any failure restores the backup.

    REQUIREMENTS
      - Deploy the new build (with SecretConfig) to the site FIRST. The old build does not know
        SecretsArePlainText and would fail to start after this script.
      - Run in an elevated PowerShell on the server that hosts the site.
      - DPAPI-protected sections can only be decrypted on the same machine. For a web farm use
        -Provider RsaProtectedConfigurationProvider and export/import the RSA key container.
      - Re-run after any deployment that overwrites Web.config.

    UNDO
      Copy the backup file back over Web.config (and redeploy the old build if needed), or decrypt
      the sections with:  aspnet_regiis -pdf "connectionStrings" "<SitePath>"
                          aspnet_regiis -pdf "appSettings" "<SitePath>"

.EXAMPLE
    .\Protect-WebConfig.ps1 -SitePath "D:\Host\NewWebShineAPI" -App Api -DryRun
    .\Protect-WebConfig.ps1 -SitePath "D:\Host\NewWebShineAPI" -App Api
    .\Protect-WebConfig.ps1 -SitePath "D:\Host\NewWebShine"    -App Ui
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $SitePath,
    [Parameter(Mandatory = $true)] [ValidateSet('Api', 'Ui')] [string] $App,
    [string] $Provider = 'DataProtectionConfigurationProvider',
    [switch] $DryRun
)
$ErrorActionPreference = 'Stop'

$configPath = Join-Path $SitePath 'Web.config'
if (-not (Test-Path $configPath)) { throw "Web.config not found in $SitePath" }

$dllName  = if ($App -eq 'Api') { 'SampWebApi.dll' } else { 'ShineWeb.dll' }
$typeName = if ($App -eq 'Api') { 'SampWebApi.DALHelper.clsEncryptDecrypt' } else { 'ShineWeb.DALHelper.clsEncryptDecrypt' }
$secretAppSettings = if ($App -eq 'Api') { @('JwtSecretKey', 'passkey') } else { @() }

$regiis = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe'
if (-not (Test-Path $regiis)) { $regiis = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe' }
if (-not (Test-Path $regiis)) { throw 'aspnet_regiis.exe (.NET Framework 4) not found.' }

[xml]$xml = Get-Content -Raw -Path $configPath
$cs = $xml.configuration.connectionStrings
$as = $xml.configuration.appSettings
if ($cs -and $cs.EncryptedData) { throw 'connectionStrings is already protected. Nothing to do.' }
if ($as -and $as.EncryptedData) { throw 'appSettings is already protected. Nothing to do.' }
$flag = $as.add | Where-Object { $_.key -eq 'SecretsArePlainText' }
if ($flag -and $flag.value -eq 'true') { throw 'SecretsArePlainText is already true. Nothing to do.' }

# The new build must be deployed: its SecretConfig understands SecretsArePlainText.
$dllPath = Join-Path $SitePath "bin\$dllName"
if (-not (Test-Path $dllPath)) { throw "$dllPath not found." }
$asm = [Reflection.Assembly]::LoadFrom($dllPath)
$secretConfigType = if ($App -eq 'Api') { 'SampWebApi.Utility.SecretConfig' } else { 'ShineWeb.Helpers.SecretConfig' }
if (-not $asm.GetType($secretConfigType)) { throw "$dllName in this site is an old build (no $secretConfigType). Deploy the new build first." }
$crypto = $asm.GetType($typeName)
if (-not $crypto) { throw "$typeName not found in $dllName." }
$decrypt = $crypto.GetMethod('Decrypt', [Type[]]@([string]))

function Try-Decrypt([string]$value) {
    try { return $decrypt.Invoke($null, @($value)) } catch { return $null }
}

$changes = New-Object System.Collections.Generic.List[string]
foreach ($add in @($cs.add)) {
    if (-not $add) { continue }
    $plain = Try-Decrypt $add.connectionString
    if ($plain -and ($plain -match '(?i)(data source|server|initial catalog|database)\s*=')) {
        if (-not $DryRun) { $add.connectionString = $plain }
        $changes.Add("connectionStrings/$($add.name): legacy ciphertext -> plain (section will be encrypted)")
    } else {
        $changes.Add("connectionStrings/$($add.name): left as is (not legacy ciphertext)")
    }
}
foreach ($key in $secretAppSettings) {
    $add = $as.add | Where-Object { $_.key -eq $key }
    if (-not $add -or [string]::IsNullOrEmpty($add.value)) { $changes.Add("appSettings/$($key): not present"); continue }
    $plain = Try-Decrypt $add.value
    if ($plain) {
        if (-not $DryRun) { $add.value = $plain }
        $changes.Add("appSettings/$($key): legacy ciphertext -> plain (section will be encrypted)")
    } else {
        throw "appSettings/$key could not be decrypted with $typeName. Stopping without changes."
    }
}
if (-not $DryRun) {
    if ($flag) { $flag.value = 'true' }
    else {
        $n = $xml.CreateElement('add'); $n.SetAttribute('key', 'SecretsArePlainText'); $n.SetAttribute('value', 'true')
        [void]$as.AppendChild($n)
    }
}
$changes.Add('appSettings/SecretsArePlainText = true')
$changes.Add("encrypt sections connectionStrings, appSettings with $Provider")

Write-Host "Planned changes for $configPath :"
$changes | ForEach-Object { Write-Host "  - $_" }
if ($DryRun) { Write-Host 'Dry run: nothing written.'; return }

$backup = "$configPath.bak-$(Get-Date -Format yyyyMMddHHmmss)"
Copy-Item -LiteralPath $configPath -Destination $backup
Write-Host "Backup: $backup"

try {
    # Plain values are on disk only between this save and the encryption below.
    $xml.Save($configPath)
    foreach ($section in 'connectionStrings', 'appSettings') {
        & $regiis -pef $section $SitePath -prov $Provider | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "aspnet_regiis failed for $section (exit $LASTEXITCODE)." }
    }
    [xml]$check = Get-Content -Raw -Path $configPath
    if (-not $check.configuration.connectionStrings.EncryptedData -or -not $check.configuration.appSettings.EncryptedData) {
        throw 'Sections are not encrypted after aspnet_regiis.'
    }
    Write-Host 'Done. Both sections are encrypted. Browse the site and log in to confirm.'
    Write-Host "Then delete the backup ($backup): it still holds the legacy-encrypted values."
}
catch {
    Copy-Item -LiteralPath $backup -Destination $configPath -Force
    Write-Error "Failed, Web.config restored from backup: $($_.Exception.Message)"
}
