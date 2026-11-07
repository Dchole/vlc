# Design reference

What was read from the Figma file, kept here because the file cannot be
queried at will (the Figma MCP server allows 20 calls a month on a free plan).

- `figma-nodes.xml`: every node of the file with its id, type, name, position
  and size. No colors or text styles, but enough to find a screen and measure
  its layout.
- `player.png`, `player-reference.tsx`: the main player frame (node `247:445`)
  as an image and as the reference code Figma generates for it, with the
  colors, sizes and spacings of the top bar, the control bar and the sidebar.
  The asset links in the code are temporary.
- `tokens.json`: the paint styles of the file, dark and light, from
  Olmo Gutierrez' implementation (see ../README.md).
- `queue-panel.md`: measures and colors of the queue panel, variant
  `491:1781`.
- `playback-reference.tsx`: Figma's reference code for Playback, file
  `kJ3O3At8xC5cqxEwD2LD1n`, node `2238:9432`. Like the player reference,
  it contains temporary asset links and is not compiled into VLC.
- `player-hide-ui.png`: the player with its interface hidden, frame
  `3328:11554` ("Player - hide UI"): the video alone in its frame, round
  corners on all four sides. "Hide UI" itself, with `Ctrl+\`, is an entry of
  the right-click menu, node `6077:14294` in `figma-nodes.xml`.
- `right-click-menu.png`: the menu of the video, node `6065:13616`, at its
  size of 292x683. Background `#191919`, texts `#8F8F8F`, shortcuts
  `#6B6B6B`, lines `#1D1D1D`, sampled from the picture. Its icons are the
  two-tone ones of `icons/figma`, copied to
  `modules/gui/qt/pixmaps/redesign/menu` (`pause-two-tone.svg` is
  `pause.svg` in the orange of the others). "Open Media" lists the open
  entries of the main menu, node `6062:13354`.
- `main-menu.png`: the main menu, behind the "…" of the top bar, node
  `6062:13354`, rows of 367.
- `audio-equalizer.png`: the equalizer of the Audio tab, node
  `6114:13610`, collapsed and expanded (preamp and ten bands).
- `onboarding-1-welcome.png`, `onboarding-2-theme.png`,
  `onboarding-3-shortcuts.png`: the three welcome screens, nodes
  `1899:3055`, `1902:3670` (the theme screen in one of its nine colors) and
  `1902:6770`.
- `miniplayer.png`: the mini player and its variants, node `970:3091`.
- `player-music.png`, `controls-waveform.png`: the music player, node
  `4767:23726`, and the control bar with the waveform, `2139:8124`.
- `sidebar.png`: the library sidebar in its ten states, node `848:1996`.
- `menu-file.png`, `menu-folder.png`, `menu-playlist.png`, `menu-sort.png`:
  the menus of a file, a folder and a playlist of the library, and its
  sort options (`2404:13340`, `2139:8935`, `2459:9389`, `856:2215`).
