#!/usr/bin/env bash
set -euo pipefail

CONTENT_BUILDER_ROOT="/Users/magic/sdk/tools/ContentBuilder"
BUILDER_OSX_DIR="$CONTENT_BUILDER_ROOT/builder_osx"
MAC_TARGET_DIR="$CONTENT_BUILDER_ROOT/content/macos"
WIN_TARGET_DIR="$CONTENT_BUILDER_ROOT/content/windows"
APP_BUILD_VDF="../scripts/app_build_4694060.vdf"
STEAM_LOGIN="jjmelior"
EXPORT_DIR="/Users/magic/vikings/pcexport"
MAC_APP_SRC="$EXPORT_DIR/HornOfTheWarlord.app"
WIN_EXE_SRC="$EXPORT_DIR/HornOfTheWarlord.exe"
WIN_PCK_SRC="$EXPORT_DIR/HornOfTheWarlord.pck"

if [ -d "$EXPORT_DIR/hornofthewarlord.app" ] && [ ! -d "$MAC_APP_SRC" ]; then
	mv "$EXPORT_DIR/hornofthewarlord.app" "$MAC_APP_SRC"
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
