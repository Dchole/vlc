#!/bin/sh
# Start a native Linux build of VLC on a screen that is only in memory and
# take a picture of its main window. Made for a headless Linux machine (such
# as a cloud container) running as root; see redesign/README.md.
#
# Usage: shot-linux.sh OUT.png [MEDIA] [WAIT_SECONDS]
#
#   BUILD   build directory holding the vlc binary (default ../vlc-build next
#           to the checkout)
#   VLC_USER  user that runs VLC, which refuses to run as root (default tester,
#           created when missing)
#
# Needs Xvfb, xdotool and ImageMagick's import.

set -e

OUT=${1:?usage: shot-linux.sh OUT.png [MEDIA] [WAIT_SECONDS]}
MEDIA=$2
WAIT=${3:-20}
SRC=$(cd "$(dirname "$0")/../.." && pwd)
: "${BUILD:=$SRC/../vlc-build}"
: "${VLC_USER:=tester}"
D=:96
LOG=/tmp/vlc-shot.log

id "$VLC_USER" >/dev/null 2>&1 || useradd -m "$VLC_USER"
VLC_HOME=$(getent passwd "$VLC_USER" | cut -d: -f6)

pkill -f "Xvfb $D" 2>/dev/null || true
setsid -f Xvfb $D -screen 0 2560x1600x24 >/dev/null 2>&1 </dev/null
sleep 2

rm -f "$LOG"
# setsid -f and runuser: started through su as a background job, VLC is
# told to quit right away.
setsid -f runuser -u "$VLC_USER" -- env HOME="$VLC_HOME" DISPLAY=$D \
    LIBGL_ALWAYS_SOFTWARE=1 "$BUILD"/vlc -vv --no-audio --no-qt-privacy-ask \
    --file-logging --logfile="$LOG" ${MEDIA:+"$MEDIA"} >/dev/null 2>&1 </dev/null
sleep "$WAIT"

# The main window is the first visible VLC window.
WID=$(DISPLAY=$D xdotool search --onlyvisible --class vlc | head -1)
if [ -n "$WID" ]; then
    DISPLAY=$D import -window "$WID" "$OUT"
else
    echo "no VLC window found, taking the whole screen" >&2
    DISPLAY=$D import -window root "$OUT"
fi

pkill -u "$VLC_USER" -x vlc 2>/dev/null || true
sleep 2
pkill -9 -u "$VLC_USER" -x vlc 2>/dev/null || true
pkill -f "Xvfb $D" 2>/dev/null || true

echo "picture: $OUT, log: $LOG"
grep -E "qt (error|critical)|cannot load|using interface module" "$LOG" \
    | cut -c1-200 | head -20 || true
