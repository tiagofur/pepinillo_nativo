param(
    [switch]$BuildFirst,
    [switch]$LaunchAfterInstall
)

$ErrorActionPreference = 'Stop'

function Get-AdbPath {
    $sdkAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (Test-Path $sdkAdb) {
        return $sdkAdb
    }

    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCommand) {
        return $adbCommand.Source
    }

    throw 'adb no esta disponible ni en PATH ni en %LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe'
}

function Get-DeviceSerials {
    param([string]$AdbPath)

    $lines = & $AdbPath devices -l | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-' }
    $phone = $null
    $wear = $null

    foreach ($line in $lines) {
        if ($line -match '^(emulator-\d+)') {
            $serial = $Matches[1]
            if ($line -match 'gwear|watch') {
                $wear = $serial
            } else {
                $phone = $serial
            }
        }
    }

    if (-not $phone) { throw 'No se encontro emulador de telefono' }
    if (-not $wear) { throw 'No se encontro emulador Wear OS' }

    return @{ Phone = $phone; Wear = $wear }
}

Push-Location $PSScriptRoot
try {
    $adb = Get-AdbPath

    if ($BuildFirst) {
        .\gradlew :app:assembleDebug :wear:assembleDebug --console=plain
    }

    $serials = Get-DeviceSerials -AdbPath $adb
    $phoneApk = Join-Path $PSScriptRoot 'app\build\outputs\apk\debug\app-debug.apk'
    $wearApk = Join-Path $PSScriptRoot 'wear\build\outputs\apk\debug\wear-debug.apk'

    if (-not (Test-Path $phoneApk)) { throw "No existe APK telefono: $phoneApk" }
    if (-not (Test-Path $wearApk)) { throw "No existe APK wear: $wearApk" }

    & $adb -s $serials.Phone install -r $phoneApk
    & $adb -s $serials.Wear install -r $wearApk

    if ($LaunchAfterInstall) {
        & $adb -s $serials.Phone shell monkey -p dev.creapolis.pepinillo -c android.intent.category.LAUNCHER 1 | Out-Null
        & $adb -s $serials.Wear shell monkey -p dev.creapolis.pepinillo -c android.intent.category.LAUNCHER 1 | Out-Null
    }

    Write-Output "Phone instalado en $($serials.Phone)"
    Write-Output "Wear instalado en $($serials.Wear)"
}
finally {
    Pop-Location
}