#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory = $true)]
    [string]$PhoneSerial,

    [Parameter(Mandatory = $true)]
    [string]$WatchSerial,

    [switch]$BuildFirst
)

$ErrorActionPreference = "Stop"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$repoRoot = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $repoRoot "android"

$appApk = Join-Path $androidDir "app\build\outputs\apk\debug\app-debug.apk"
$wearApk = Join-Path $androidDir "wear\build\outputs\apk\debug\wear-debug.apk"

if ($BuildFirst) {
    Write-Host "Compilando APKs debug..." -ForegroundColor Yellow
    Push-Location $androidDir
    try {
        & .\gradlew.bat :app:assembleDebug :wear:assembleDebug
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path $appApk)) {
    throw "No se encontro APK de telefono: $appApk"
}
if (-not (Test-Path $wearApk)) {
    throw "No se encontro APK de reloj: $wearApk"
}

Write-Host "Instalando en telefono ($PhoneSerial)..." -ForegroundColor Cyan
& $adb -s $PhoneSerial install -r "$appApk"

Write-Host "Instalando en reloj ($WatchSerial)..." -ForegroundColor Cyan
& $adb -s $WatchSerial install -r "$wearApk"

Write-Host "Listo. Instalacion completada en ambos dispositivos." -ForegroundColor Green
