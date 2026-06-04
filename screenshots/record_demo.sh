#!/bin/bash
ADB="/Users/tiagofur/Library/Android/sdk/platform-tools/adb"
DEVICE="emulator-5554"

echo "Limpiando archivos viejos..."
$ADB -s $DEVICE shell rm -f /sdcard/demo.mp4

echo "Iniciando grabacion en segundo plano (duracion maxima 18 segundos)..."
$ADB -s $DEVICE shell screenrecord --time-limit 18 /sdcard/demo.mp4 &
RECORD_PID=$!

sleep 2

echo "Iniciando el temporizador..."
$ADB -s $DEVICE shell input tap 640 2232
sleep 3

echo "Poniendo la app en segundo plano..."
$ADB -s $DEVICE shell input keyevent 3
sleep 2

echo "Abriendo panel de notificaciones..."
$ADB -s $DEVICE shell cmd statusbar expand-notifications
sleep 4

echo "Cerrando panel de notificaciones..."
$ADB -s $DEVICE shell cmd statusbar collapse
sleep 1

echo "Volviendo a abrir la app..."
$ADB -s $DEVICE shell monkey -p dev.creapolis.pepinillo -c android.intent.category.LAUNCHER 1
sleep 3

echo "Deteniendo grabacion..."
wait $RECORD_PID

echo "Descargando video..."
mkdir -p /Users/tiagofur/dev/pepinillo_nativo/screenshots
$ADB -s $DEVICE pull /sdcard/demo.mp4 /Users/tiagofur/dev/pepinillo_nativo/screenshots/fgs_demo.mp4

echo "Limpiando el emulador..."
$ADB -s $DEVICE shell rm -f /sdcard/demo.mp4

echo "Proceso completado!"
