#!/usr/bin/env bash
set -euo pipefail

CONTENT_BUILDER_ROOT="/Users/magic/sdk/tools/ContentBuilder"
BUILDER_OSX_DIR="$CONTENT_BUILDER_ROOT/builder_osx"
MAC_TARGET_DIR="$CONTENT_BUILDER_ROOT/content/macos"
WIN_TARGET_DIR="$CONTENT_BUILDER_ROOT/content/windows"
APP_BUILD_VDF="../scripts/app_build_4380120.vdf"
STEAM_LOGIN="jjmelior"
EXPORT_DIR="/Users/magic/vikings/pcexport"
PROJECT_DIR="/Users/magic/vikings"
MAC_EXPORT_PRESET="macos"
WIN_EXPORT_PRESET="windows"
MAC_APP_SRC="$EXPORT_DIR/HornOfTheWarlord.app"
WIN_EXE_SRC="$EXPORT_DIR/HornOfTheWarlord.exe"
WIN_PCK_SRC="$EXPORT_DIR/HornOfTheWarlord.pck"
LOWERCASE_MAC_APP_SRC="$EXPORT_DIR/hornofthewarlord.app"

mkdir -p "$EXPORT_DIR"

rm -rf "$MAC_APP_SRC" "$LOWERCASE_MAC_APP_SRC" "$WIN_EXE_SRC" "$WIN_PCK_SRC"
find "$EXPORT_DIR" -maxdepth 1 -type f -name 'HornOfTheWarlord.pck-*' -delete

godot4 --headless --path "$PROJECT_DIR" --export-release "$WIN_EXPORT_PRESET" "$WIN_EXE_SRC"
godot4 --headless --path "$PROJECT_DIR" --export-release "$MAC_EXPORT_PRESET" "$MAC_APP_SRC"

if [ -d "$LOWERCASE_MAC_APP_SRC" ] && [ ! -d "$MAC_APP_SRC" ]; then
	mv "$LOWERCASE_MAC_APP_SRC" "$MAC_APP_SRC"
fi

if [ ! -d "$MAC_APP_SRC" ]; then
	echo "Missing macOS app bundle: $MAC_APP_SRC"
	exit 1
fi

if [ ! -f "$WIN_EXE_SRC" ]; then
	echo "Missing Windows executable: $WIN_EXE_SRC"
	exit 1
fi

if [ ! -f "$WIN_PCK_SRC" ]; then
	echo "Missing PCK file: $WIN_PCK_SRC"
	exit 1
fi

mkdir -p "$MAC_TARGET_DIR" "$WIN_TARGET_DIR"

MAC_APP_DST="$MAC_TARGET_DIR/HornOfTheWarlord.app"
WIN_EXE_DST="$WIN_TARGET_DIR/HornOfTheWarlord.exe"
WIN_PCK_DST="$WIN_TARGET_DIR/HornOfTheWarlord.pck"

rm -rf "$MAC_APP_DST"
cp -R "$MAC_APP_SRC" "$MAC_APP_DST"
cp -f "$WIN_EXE_SRC" "$WIN_EXE_DST"
cp -f "$WIN_PCK_SRC" "$WIN_PCK_DST"

cd "$BUILDER_OSX_DIR"
bash ./steamcmd.sh +login "$STEAM_LOGIN" +run_app_build "$APP_BUILD_VDF" +quit
