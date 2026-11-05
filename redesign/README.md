# VLC redesign

This fork implements the VLC interface redesign by
[Juxtopposed](https://juxtopposed.com) on top of VLC 4 (the Qt/QML interface in
`modules/gui/qt`).

- Video: [I Redesigned VLC After 25 Years](https://www.youtube.com/watch?v=ERFeOgqk324)
- Design file: [VLC Redesign on Figma Community](https://www.figma.com/community/file/1691465999134370980)

The design is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
by Juxtopposed. VLC itself stays under its own licenses, see `COPYING`.

The SVG export of the Figma icon library in `redesign/icons/figma` and the
list of paint styles the palette was checked against come from
[Olmo Gutierrez' implementation](https://github.com/Olmo-Gutierrez/VLC-juxtopposed)
of the same redesign, as does the idea for the frame around the video.

The preferences window and keyboard shortcut editor started from
[dsojevic's VLC fork](https://github.com/dsojevic/vlc/tree/juxtopposed-redesign)
at `43283e42a8`. The Windows version uses styled QtQuick.Templates controls
and a curated catalog based on the local Figma reference. The comparison,
approved exceptions and missing rows are in [VERIFICATION.md](VERIFICATION.md)
and [design/preferences-audit.md](design/preferences-audit.md).

This is an unofficial project, it is not affiliated with VideoLAN.

## Building on Windows

Docker Desktop is the only requirement. The build runs in the same image
VideoLAN's CI uses and reuses their prebuilt third-party libraries.

```powershell
.\redesign\docker-build.ps1        # everything, takes a while the first time
.\redesign\docker-build.ps1 qt     # after changing only modules/gui/qt
.\build-win64\vlc.exe
```

The build keeps its settings in `build-win64\portable`, delete that folder to
start over with the defaults.

## Building on Linux

On Linux itself this is VLC's usual build (`./bootstrap`, `./configure`,
`make`, then `./vlc` from the build directory), with Qt 6 and its SVG image
plugin installed.

On Ubuntu 24.04 (Qt 6.4), these packages are enough for the player and the
Qt interface:

```sh
sudo apt-get install --no-install-recommends \
  autoconf automake libtool gettext autopoint flex bison pkg-config \
  lua5.2 liblua5.2-dev libavcodec-dev libavformat-dev libavutil-dev \
  libswscale-dev libswresample-dev liba52-0.7.4-dev libmad0-dev libmpeg2-4-dev \
  libxcb1-dev libxcb-shm0-dev libxcb-composite0-dev libxcb-xv0-dev \
  libxcb-randr0-dev libxcb-keysyms1-dev libxcb-damage0-dev libxcb-xfixes0-dev \
  libx11-dev libx11-xcb-dev libxkbcommon-dev libxkbcommon-x11-dev \
  libxi-dev libxext-dev libxinerama-dev libxpm-dev \
  libgl-dev libegl-dev libgles-dev libdrm-dev libwayland-dev wayland-protocols \
  libpulse-dev libasound2-dev libdbus-1-dev libgcrypt20-dev libgnutls28-dev \
  libxml2-dev libfreetype-dev libfontconfig-dev libfribidi-dev libharfbuzz-dev \
  libass-dev libtag1-dev libsqlite3-dev libarchive-dev libvorbis-dev libogg-dev \
  libflac-dev libopus-dev libtheora-dev libmatroska-dev libebml-dev \
  libdvbpsi-dev libmpg123-dev libsamplerate0-dev libva-dev libvdpau-dev \
  libplacebo-dev zlib1g-dev \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev \
  qt6-declarative-private-dev qt6-svg-dev qt6-wayland-dev qt6-shadertools-dev \
  qt6-5compat-dev qml6-module-qtquick qml6-module-qtquick-templates \
  qml6-module-qtquick-controls qml6-module-qtquick-layouts \
  qml6-module-qtquick-window qml6-module-qtqml qml6-module-qtqml-models \
  qml6-module-qtqml-workerscript qml6-module-qttest
./bootstrap
mkdir ../vlc-build && cd ../vlc-build && ../vlc/configure && make -j"$(nproc)"
```

`make` rewrites the translations in `po/`; `git checkout -- po` puts them
back.

On a machine without a screen (a server or a cloud container), add `xvfb
xdotool imagemagick` and let `redesign/tools/shot-linux.sh` start the player
in memory and take a picture of its window:

```sh
ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30:duration=60 \
  -f lavfi -i sine=duration=60 -pix_fmt yuv420p -shortest \
  redesign/tools/Videos/clip-m.mp4
redesign/tools/shot-linux.sh /tmp/player.png redesign/tools/Videos/clip-m.mp4
```

From Windows, the same can be done in VideoLAN's Debian image, to see that a
change still compiles and runs there:

```powershell
.\redesign\docker-build-linux.ps1          # everything, takes a while the first time
.\redesign\docker-build-linux.ps1 qt       # after changing only modules/gui/qt
.\redesign\docker-build-linux.ps1 shot -Media clip-m.mp4
```

`shot` starts the player on a screen that is only in memory, plays the file
from `redesign\tools\Videos` and puts a picture of the screen and the log
into `build-linux\`. That image has no SVG plugin for Qt, so the volume cone
and the cover placeholder are missing in its pictures. The build stays in a
Docker volume and is of no use outside of the image.

## Icons

VLC draws its icons with a font, `modules/gui/qt/pixmaps/VLCIcons.ttf`. The
glyphs listed in `VLCIcons.json` with a path in `icons/redesign/` are made
from the Figma icons:

```powershell
.\redesign\icons\update.ps1
```
