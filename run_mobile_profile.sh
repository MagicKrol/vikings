#!/bin/bash

# Launch the game in desktop windows that approximate common landscape mobile aspect ratios.

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_EXEC="${GODOT_EXEC:-godot4}"

if ! command -v "$GODOT_EXEC" >/dev/null 2>&1; then
	GODOT_EXEC="/Applications/Godot.app/Contents/MacOS/Godot"
fi

show_help() {
	echo "Usage: $0 PROFILE [--editor] [--fullscreen]"
	echo
	echo "Profiles:"
	echo "  desktop_16_9   1920x1080"
	echo "  phone_18_9     2160x1080"
	echo "  phone_19_5_9   2340x1080"
	echo "  phone_20_9     2400x1080"
	echo "  small_16_9     1280x720"
	echo "  small_wide     1600x720"
	echo
	echo "Examples:"
	echo "  $0 phone_20_9"
	echo "  $0 small_wide --editor"
	echo "  $0 phone_20_9 --fullscreen"
	echo
	echo "Optional:"
	echo "  GODOT_EXEC=/path/to/godot $0 phone_20_9"
}

if [[ $# -lt 1 || "$1" == "--help" || "$1" == "-h" ]]; then
	show_help
	exit 0
fi

PROFILE="$1"
MODE_ARG=""
WINDOW_MODE_ARG="--windowed"

shift
while [[ $# -gt 0 ]]; do
	case "$1" in
		--editor)
			MODE_ARG="--editor"
			;;
		--fullscreen)
			WINDOW_MODE_ARG="--fullscreen"
			;;
		*)
			echo "Unknown option: $1"
			echo
			show_help
			exit 1
			;;
	esac
	shift
done

case "$PROFILE" in
	desktop_16_9)
		RESOLUTION="1920x1080"
		;;
	phone_18_9)
		RESOLUTION="2160x1080"
		;;
	phone_19_5_9)
		RESOLUTION="2340x1080"
		;;
	phone_20_9)
		RESOLUTION="2400x1080"
		;;
	small_16_9)
		RESOLUTION="1280x720"
		;;
	small_wide)
		RESOLUTION="1600x720"
		;;
	*)
		echo "Unknown profile: $PROFILE"
		echo
		show_help
		exit 1
		;;
esac

echo "Launching $PROFILE at $RESOLUTION"
echo "Godot: $GODOT_EXEC"

exec "$GODOT_EXEC" $MODE_ARG --path "$PROJECT_DIR" "$WINDOW_MODE_ARG" --resolution "$RESOLUTION" -- "--mobile-profile-resolution=$RESOLUTION"
