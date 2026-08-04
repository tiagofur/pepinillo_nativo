<#
.SYNOPSIS
  Create a self-signed code-signing certificate for LOCAL MSIX sideload testing only.

.DESCRIPTION
  Generates a PFX under windows/certs/ (gitignored recommended) with subject CN=PepinilloDev
  matching Package.appxmanifest Publisher for dev packages.

  DO NOT use this certificate for Microsoft Store submission.
  Production packages must be signed with the Partner Center association / Store certificate.

.PARAMETER Password
  PFX password. Default: PepinilloDev!

.PARAMETER OutDir
  Output directory for PFX / CER. Default: windows/certs

.EXAMPLE
  .\create-dev-cert.ps1
  .\create-dev-cert.ps1 -Password 'YourLocalOnlySecret'
#>
[CmdletBinding()]
param(
    [string] $Password = "PepinilloDev!",
    [string] $OutDir = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WindowsRoot = Resolve-Path (Join-Path $ScriptDir "..")
if (-not $OutDir) {
    $OutDir = Join-Path $WindowsRoot "certs"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Subject = "CN=PepinilloDev"
$PfxPath = Join-Path $OutDir "PepinilloDev.pfx"
$CerPath = Join-Path $OutDir "PepinilloDev.cer"

Write-Host "==> Creating self-signed cert: $Subject"
$secure = ConvertTo-SecureString -String $Password -Force -AsPlainText

$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject $Subject `
    -KeyUsage DigitalSignature `
    -FriendlyName "Pepinillo Dev Sideload (NOT for Store)" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
    -NotAfter (Get-Date).AddYears(2)

Export-PfxCertificate -Cert $cert -FilePath $PfxPath -Password $secure | Out-Null
Export-Certificate -Cert $cert -FilePath $CerPath | Out-Null

Write-Host "    PFX: $PfxPath"
Write-Host "    CER: $CerPath"
Write-Host ""
Write-Host "Install trust (elevated PowerShell, once per machine):"
Write-Host "  Import-Certificate -FilePath `"$CerPath`" -CertStoreLocation Cert:\LocalMachine\TrustedPeople"
Write-Host ""
Write-Host "Sign MSIX:"
Write-Host "  signtool sign /fd SHA256 /f `"$PfxPath`" /p `"$Password`" path\to\package.msix"
Write-Host ""
Write-Host "Thumbprint: $($cert.Thumbprint)"
