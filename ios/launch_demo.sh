#!/bin/bash

# launch_demo.sh — Pepinillo Demo Data Launcher
# This script launches the Pepinillo app in the iOS Simulator with demo data seeding enabled.

set -e

# Configuration
SCHEME="Pepinillo Dev"
BUNDLE_ID="com.pepinillo.app"

# Use provided device ID or detect first booted
if [ -n "$1" ]; then
    DEVICE="$1"
else
    DEVICE=$(xcrun simctl list devices booted | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n 1)
fi

if [ -z "$DEVICE" ]; then
    echo "❌ No hay ningún simulador encendido. Por favor, abrí uno en Xcode (Open Simulator)."
    exit 1
fi

# Detect App Path (Local build or default DerivedData)
LOCAL_APP="ios/build/DerivedData/Build/Products/Debug-iphonesimulator/Pepinillo.app"
DEFAULT_APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Pepinillo-*/Build/Products/Debug-iphonesimulator/Pepinillo.app 2>/dev/null | head -n 1)

if [ -d "$LOCAL_APP" ]; then
    APP_PATH="$LOCAL_APP"
elif [ -d "$DEFAULT_APP" ]; then
    APP_PATH="$DEFAULT_APP"
else
    echo "❌ No se encontró el binario de la app. Por favor, compilá el proyecto primero."
    exit 1
fi

echo "🚀 Lanzando Pepinillo desde: $APP_PATH"
echo "📱 Dispositivo: $DEVICE"
echo "📊 Sembrando datos de demo y activando Modo Pro..."

# Install and Launch
xcrun simctl install "$DEVICE" "$APP_PATH"
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -seedDemoData -proMode

echo "✅ ¡Listo! La app debería abrirse con datos en unos segundos."
echo "💡 Nota: Si la app no está instalada, primero corre 'xcodegen generate' y compilá desde Xcode."
