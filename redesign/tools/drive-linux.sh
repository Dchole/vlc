#!/bin/sh
# Start a native Linux build of VLC on a screen that is only in memory and
# leave it running, so that it can be driven with xdotool and pictured with
# ImageMagick's import. Companion of shot-linux.sh, see redesign/README.md.
# With openbox installed it runs as window manager, for full screen.
#
# Usage: drive-linux.sh start [MEDIA] [VLC ARGS...]
#        drive-linux.sh stop
#
#   BUILD, VLC_USER  as in shot-linux.sh
#   VLC_AOUT  an audio output, such as "dummy" for one that plays nothing;
#             without it VLC runs with --no-audio
#
# While it runs, DISPLAY=:96 reaches the screen, for instance:
#   DISPLAY=:96 xdotool search --onlyvisible --class vlc
#   DISPLAY=:96 import -window root /tmp/screen.png

set -e

SRC=$(cd "$(dirname "$0")/../.." && pwd)
: "${BUILD:=$SRC/../vlc-build}"
: "${VLC_USER:=tester}"
D=:96
LOG=/tmp/vlc-drive.log

case "$1" in
    start)
        shift
        MEDIA=$1
        [ $# -gt 0 ] && shift
        id "$VLC_USER" >/dev/null 2>&1 || useradd -m "$VLC_USER"
        VLC_HOME=$(getent passwd "$VLC_USER" | cut -d: -f6)
        pkill -u "$VLC_USER" -x vlc 2>/dev/null || true
        pkill -f "Xvfb $D" 2>/dev/null || true
        sleep 1
        setsid -f Xvfb $D -screen 0 1920x1080x24 >/dev/null 2>&1 </dev/null
        sleep 2
        # Full screen and maximizing need a window manager.
        if command -v openbox >/dev/null; then
            DISPLAY=$D setsid -f openbox >/dev/null 2>&1 </dev/null
            sleep 1
        fi
        rm -f "$LOG"
        if [ -n "$VLC_AOUT" ]; then AUDIO="--aout=$VLC_AOUT"; else AUDIO="--no-audio"; fi
        setsid -f runuser -u "$VLC_USER" -- env HOME="$VLC_HOME" DISPLAY=$D \
            LIBGL_ALWAYS_SOFTWARE=1 "$BUILD"/vlc -vv "$AUDIO" \
            --no-qt-privacy-ask --file-logging --logfile="$LOG" "$@" \
            ${MEDIA:+"$MEDIA"} >/dev/null 2>&1 </dev/null
        echo "started on $D, log: $LOG"
        ;;
    stop)
        pkill -u "$VLC_USER" -x vlc 2>/dev/null || true
        sleep 2
        pkill -9 -u "$VLC_USER" -x vlc 2>/dev/null || true
        pkill -x openbox 2>/dev/null || true
        pkill -f "Xvfb $D" 2>/dev/null || true
        ;;
    *)
        echo "usage: $0 start [MEDIA] [VLC ARGS...] | stop" >&2
        exit 1
        ;;
esac
