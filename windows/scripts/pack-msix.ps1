<#
.SYNOPSIS
  Publish Pepinillo.WinUI as an MSIX package for sideload or Partner Center upload.

.DESCRIPTION
  Runs `dotnet publish` with Windows App SDK single-project MSIX settings.
  Produces an unsigned package by default (AppxPackageSigningEnabled=false).
  For local install testing, create a self-signed cert (create-dev-cert.ps1) and sign with signtool.

  Version scheme (Package.appxmanifest Identity Version): Major.Minor.Build.Revision
  Keep in sync with windows/Directory.Build.props (PepinilloPackageVersion).

.PARAMETER Configuration
  Build configuration. Default: Release

.PARAMETER Runtime
  RID: win-x64 or win-arm64. Default: win-x64

.PARAMETER OutputDir
  Folder that receives copied .msix / .msixbundle artifacts. Default: windows/artifacts/msix

.EXAMPLE
  .\pack-msix.ps1 -Runtime win-x64
  .\pack-msix.ps1 -Runtime win-arm64 -Configuration Release
#>
[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",

    [ValidateSet("win-x64", "win-arm64")]
    [string] $Runtime = "win-x64",

    [string] $OutputDir = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WindowsRoot = Resolve-Path (Join-Path $ScriptDir "..")
$Project = Join-Path $WindowsRoot "Pepinillo.WinUI\Pepinillo.WinUI.csproj"

if (-not $OutputDir) {
    $OutputDir = Join-Path $WindowsRoot "artifacts\msix"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host "==> Publishing Pepinillo.WinUI ($Configuration / $Runtime) as MSIX..."
Write-Host "    Project: $Project"
Write-Host "    Output:  $OutputDir"

# Windows App SDK 1.6 single-project MSIX:
# - WindowsPackageType=MSIX enables package generation
# - WindowsAppSDKSelfContained improves Store/sideload reliability (framework not required)
# - AppxPackageSigningEnabled=false leaves package unsigned for CI / Partner Center re-sign
# - AppxBundle=Never produces per-RID .msix (simpler than multi-arch bundle for first upload)
$publishArgs = @(
    "publish", $Project,
    "-c", $Configuration,
    "-r", $Runtime,
    "--self-contained", "true",
    "-p:WindowsPackageType=MSIX",
    "-p:WindowsAppSDKSelfContained=true",
    "-p:AppxPackageSigningEnabled=false",
    "-p:GenerateAppInstallerFile=false",
    "-p:AppxBundle=Never",
    "-p:AppxPackageDir=$OutputDir\",
    "-p:GenerateAppxPackageOnBuild=true"
)

& dotnet @publishArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "dotnet publish failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

# Collect packages into a flat artifacts layout
$msixFiles = Get-ChildItem -Path $OutputDir -Recurse -Include *.msix, *.msixbundle -ErrorAction SilentlyContinue
if (-not $msixFiles -or $msixFiles.Count -eq 0) {
    Write-Warning "No .msix found under $OutputDir. Checking default AppPackages..."
    $fallback = Join-Path $WindowsRoot "Pepinillo.WinUI\AppPackages"
    if (Test-Path $fallback) {
        $msixFiles = Get-ChildItem -Path $fallback -Recurse -Include *.msix, *.msixbundle -ErrorAction SilentlyContinue
        foreach ($f in $msixFiles) {
            Copy-Item $f.FullName -Destination $OutputDir -Force
        }
        $msixFiles = Get-ChildItem -Path $OutputDir -Filter *.msix* -ErrorAction SilentlyContinue
    }
}

if ($msixFiles -and $msixFiles.Count -gt 0) {
    Write-Host "==> MSIX artifacts:"
    foreach ($f in $msixFiles) {
        Write-Host "    $($f.FullName) ($([math]::Round($f.Length / 1MB, 2)) MB)"
    }
} else {
    Write-Warning @"
No MSIX package was located. On a full Windows + Windows SDK machine this usually means:
  - Missing Windows SDK / MakeAppx tooling
  - Publish produced unpackaged output only

Fallback (manual packaging layout):
  1. dotnet publish ... -p:WindowsPackageType=None -o publish\$Runtime
  2. Build a packaging layout (AppxManifest + binaries)
  3. MakeAppx pack /d layout /p Pepinillo.msix
"@
}

Write-Host ""
Write-Host "==> Local sideload signing (optional, NOT for Store):"
Write-Host "    1. .\create-dev-cert.ps1"
Write-Host "    2. signtool sign /fd SHA256 /a /f path\to\PepinilloDev.pfx /p <password> package.msix"
Write-Host "    3. Install cert to Local Machine > Trusted People, then double-click MSIX"
Write-Host ""
Write-Host "Store submissions: upload unsigned or Partner Center–signed packages per Microsoft docs."
Write-Host "Done."
