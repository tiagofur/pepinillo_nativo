#!/usr/bin/env pwsh
# validate_wear_sync.ps1
# Ejecutar después de parear los emuladores para verificar la sync.
# Uso: .\scripts\validate_wear_sync.ps1

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$phoneSerial = "emulator-5554"
$watchSerial = "emulator-5556"

function Get-WatchScreen {
    & $adb -s $watchSerial shell uiautomator dump /sdcard/v_ws.xml 2>&1 | Out-Null
    & $adb -s $watchSerial pull /sdcard/v_ws.xml "$env:TEMP\v_ws.xml" 2>&1 | Out-Null
    if (Test-Path "$env:TEMP\v_ws.xml") {
        $xml = [System.IO.File]::ReadAllText("$env:TEMP\v_ws.xml")
        [regex]::Matches($xml, 'text="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne "" } | Select-Object -Unique
    }
}

Write-Host "`n=== PEPINILLO WEAR SYNC VALIDATOR ===" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'HH:mm:ss')`n"

# --- 1. Dispositivos conectados ---
Write-Host "1. Dispositivos ADB:" -ForegroundColor Yellow
$devices = & $adb devices
$phoneOk = $devices | Select-String $phoneSerial
$watchOk  = $devices | Select-String $watchSerial
$phoneState = if ($phoneOk) { "[OK] $phoneSerial (teléfono)" } else { "[FALTA] $phoneSerial" }
$watchState = if ($watchOk)  { "[OK] $watchSerial (reloj)"   } else { "[FALTA] $watchSerial"  }
Write-Host "   $phoneState"
Write-Host "   $watchState"

# --- 2. TCP forward 5601 ---
Write-Host "`n2. Port Forward TCP 5601:" -ForegroundColor Yellow
$fwds = & $adb -s $phoneSerial forward --list 2>&1
if ($fwds -match "5601") {
    Write-Host "   [OK] tcp:5601 forward activo" -ForegroundColor Green
} else {
    Write-Host "   [!] Sin forward - aplicando..." -ForegroundColor DarkYellow
    & $adb -s $phoneSerial forward tcp:5601 tcp:5601 | Out-Null
    Write-Host "   [OK] Forward aplicado" -ForegroundColor Green
}

# --- 3. FocusTimerService en teléfono ---
Write-Host "`n3. FocusTimerService (teléfono):" -ForegroundColor Yellow
$svc = & $adb -s $phoneSerial shell dumpsys activity services dev.creapolis.pepinillo 2>&1
if ($svc -match "isForeground=true") {
    Write-Host "   [OK] Timer corriendo (foreground service activo)" -ForegroundColor Green
} else {
    Write-Host "   [!] Timer NO corre — Inicia una sesión de foco en la app" -ForegroundColor Red
}

# --- 4. WearSyncListenerService en reloj ---
Write-Host "`n4. WearSyncListenerService (reloj):" -ForegroundColor Yellow
$wls = & $adb -s $watchSerial shell dumpsys package dev.creapolis.pepinillo 2>&1 | Select-String "WearSyncListenerService"
if ($wls) {
    Write-Host "   [OK] Servicio registrado en el reloj" -ForegroundColor Green
} else {
    Write-Host "   [!] Servicio no encontrado — reinstala la app en el reloj" -ForegroundColor Red
}

# --- 5. Pantalla del reloj ---
Write-Host "`n5. Pantalla del reloj (DiagnosticsScreen):" -ForegroundColor Yellow
$screenTexts = Get-WatchScreen
if ($screenTexts) {
    $peerLine  = $screenTexts | Select-String "Peers Data Layer"
    $connLine  = $screenTexts | Select-String "Conexion"
    $syncLine  = $screenTexts | Select-String "Sync events"
    $timerLine = $screenTexts | Select-String "Timer:"

    if ($peerLine) {
        $peers = ([regex]::Match($peerLine, "\d+")).Value
        if ([int]$peers -gt 0) {
            Write-Host "   [OK] $peerLine" -ForegroundColor Green
        } else {
            Write-Host "   [!] $peerLine  ← emuladores NO pareados" -ForegroundColor Red
        }
    }
    if ($connLine)  { Write-Host "   $connLine" -ForegroundColor $(if ($connLine -match "Activa") { "Green" } else { "Red" }) }
    if ($timerLine) { Write-Host "   $timerLine" -ForegroundColor $(if ($timerLine -match "Running") { "Green" } else { "DarkYellow" }) }
    if ($syncLine)  { Write-Host "   $syncLine" }
} else {
    Write-Host "   [!] No se pudo capturar la pantalla del reloj" -ForegroundColor Red
}

# --- 6. Logcat snippet (últimos eventos Data Layer) ---
Write-Host "`n6. Últimos logs Data Layer (reloj, 10 líneas):" -ForegroundColor Yellow
$logSnip = & $adb -s $watchSerial shell logcat -t 100 2>&1 | Select-String -Pattern "WearSyncListenerService|onDataChanged|putDataItem|WearDataLayer|DataClient" | Select-Object -Last 10
if ($logSnip) {
    $logSnip | ForEach-Object { Write-Host "   $_" }
} else {
    Write-Host "   (sin eventos recientes de Data Layer)" -ForegroundColor DarkYellow
}

Write-Host "`n=== FIN VALIDACIÓN ===" -ForegroundColor Cyan
Write-Host "Para parear, abrir Android Studio → Device Manager → Pixel 9 Pro → ... → Pair Wearable`n"
