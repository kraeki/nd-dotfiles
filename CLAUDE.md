# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for a NixOS system with Hyprland window manager. It uses GNU Stow for managing dotfiles and NixOS flakes for system configuration. The NixOS side is organized as a module library ("the distro") consumed by thin host configs — see `docs/ARCHITECTURE.md` for the roadmap.

## Repository Structure

The repository has two main configuration approaches:

### 1. Stow-Managed Dotfiles
Application-specific dotfiles organized in the `dotfiles/` subdirectory (e.g., `dotfiles/hypr/`, `dotfiles/nvim/`, `dotfiles/waybar/`). Each directory contains the `.config/` hierarchy that gets symlinked to `$HOME` via Stow.

### 2. NixOS Configuration (flake at repository root)
- `flake.nix` - Flake exporting `nixosModules.default`, `homeManagerModules.default`, and host "naptop"
- `modules/nixos/` - The system profile behind `nd.*` options (core, desktop, theme, networking, power, docker, gaming, locale). Import + `nd.enable = true` turns everything on; individual modules can be toggled (`nd.gaming.enable = false;`)
- `modules/home/` - Home-manager profile behind `nd.*` options (shell, chrome)
- `hosts/naptop/` - This machine only: hardware config, boot/kernel quirks (Framework 16 AMD), its user account, `system.stateVersion`
- `users/kraeki/home.nix` - Personal home config: packages, aliases, syncthing
- `pkgs/` - Custom packages not in nixpkgs (herdr, tldraw-offline), used via `pkgs.callPackage`

## Common Commands

### Dotfiles Management
```bash
# Install/update all dotfiles (creates symlinks)
make

# Remove all symlinked dotfiles
make delete
```

### NixOS System Management
```bash
# Rebuild and switch to new NixOS configuration (from repo root)
sudo nixos-rebuild switch --flake .#naptop     # or: make switch

# Test configuration without switching
sudo nixos-rebuild test --flake .#naptop

# Build configuration without activating
sudo nixos-rebuild build --flake .#naptop
```

### Flakes
```bash
# Update all flake inputs (from repo root)
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs
```

### Bootstrap a fresh machine
```bash
curl -sL https://raw.githubusercontent.com/kraeki/nd-dotfiles/main/install.sh | sh
```

## Key Architecture Details

### Package Management Split
- **System packages** (`environment.systemPackages` in `modules/nixos/*.nix`): Core system tools, desktop environment components, CLI utilities — each in the module it belongs to (host-specific hardware tools stay in `hosts/naptop/default.nix`)
- **User packages** (`home.packages` in `users/kraeki/home.nix`): GUI applications, productivity tools, entertainment software

This separation keeps system concerns distinct from user preferences and makes home-manager configuration portable. When adding options, keep the discipline: identity-shaped config goes in `modules/` behind an `nd.*` option; only hardware truth and per-machine choices go in `hosts/`.

### Hyprland Configuration
- Main config: `dotfiles/hypr/.config/hypr/hyprland.lua` (Hyprland 0.55+ Lua config)
  - Hyprland loads `hyprland.lua` in preference to `hyprland.conf`. This file is
    authoritative and self-contained: keybindings, window rules, animations, theme,
    and a static fallback monitor were all ported into it from the old modular
    `*.conf` files (which have been removed).
  - Lua specifics: bindings use `hl.bind(...)` / `hl.dsp.*`; runtime dispatch from
    scripts uses `hyprctl dispatch 'hl.dsp.*'` and `hyprctl eval 'hl.*'` (the legacy
    `hyprctl dispatch <legacy>` / `hyprctl keyword` forms are rejected).
- `hyprlock.conf` - still hyprlang; read by the separate hyprlock program (not part
  of the Lua config).
- Monitors: **fully native, no daemon**. Declarative `hl.monitor` rules in the
  MONITORS block of `hyprland.lua` (eDP-1 + the two Dells by `desc:`, plus a
  catch-all first since Hyprland applies the LAST matching rule). Hyprland
  re-applies these automatically on every hotplug, so docking "just works".
  - The laptop panel (eDP-1) is toggled by **lid-switch binds** (clamshell
    docking): `switch:on:Lid Switch` (lid closed) disables eDP-1;
    `switch:off:Lid Switch` (lid open) re-enables it @ scale 1.333. Required
    because a closing lid does NOT disconnect eDP at the DRM level (no hotplug).
    `services.logind.settings.Login.HandleLidSwitchDocked = "ignore"` keeps
    logind from suspending while docked so Hyprland gets the event.
  - This replaced **kanshi** (and a short-lived socket2 listener). No
    wlr-output-management daemon (kanshi/shikane/way-displays) can do reliable
    dock↔undock on Hyprland: disabling a head drops it from the protocol list
    (Hyprland #1274), so undock never re-enables the internal panel.
- Scripts location: `~/.local/share/bin/` (referenced as `$srcPath` in config)
- Manual monitor override: `dotfiles/hypr/.config/hypr/bin/monitor-docked-home.sh`
  forces the docked layout. It applies via `hyprctl eval 'hl.monitor(...)'` and
  sets `disabled=` explicitly, because a mode/position rule alone does NOT clear
  a previously-set `disabled` flag. Its counterpart `monitor-laptop-only.sh`
  (`Super+M`, eDP-1 on + Dells off) was **removed** along with its bind when
  `Super+M` became the layout toggle; there is no longer a key that switches the
  Dells off while docked.
- `toggle-laptop-display [toggle|on|off|status] [-q]` in
  `dotfiles/hypr/.local/share/bin/` is the **single implementation** of "panel
  on/off" — `lid-close.sh` / `lid-open.sh` are now thin `--quiet` wrappers around
  `off` / `on`, so the headless guard and the enable-retry live in one place.
  It refuses to disable eDP-1 when it is the only active monitor (that is what
  left the panel dark until a power cycle), and retries+verifies on enable
  because a just-resumed Hyprland reports "ok" without committing.
  `dotfiles/hypr/.local/share/applications/toggle-laptop-display.desktop` exposes
  it to **vicinae** and any other XDG launcher (plus On/Off desktop actions). Its
  `Exec=` is a bare absolute path: the desktop-entry spec only defines
  double-quote quoting and needs `$` escaped inside it, so an `sh -c '…$HOME…'`
  wrapper is parser-dependent. New XDG entries need a vicinae restart to appear.
- `toggle-display-mirror [toggle|on|off|status] [-q]` (same directory,
  `Super+Ctrl+Alt+Delete`) is **presentation mirroring**: every enabled external
  becomes a copy of eDP-1, so what is on the laptop shows on the projector.
  - **The mirror source must be an enabled monitor.** Docked with the lid shut,
    eDP-1 is disabled and `mirror="eDP-1"` returns `ok` while doing nothing —
    `mirrorOf` stays `none`. So `on` lights the panel first (delegating to
    `toggle-laptop-display on`) and records whether it was dark.
  - **`hyprctl monitors` lists neither disabled NOR mirrored outputs** — an
    output vanishes from it the moment it becomes a mirror. All state queries
    here use `hyprctl -j monitors all` and filter `.disabled` themselves. This
    also means `toggle-laptop-display`'s "only active monitor" guard would
    misfire while mirroring, so `off` clears the mirrors and *waits* for that to
    land before switching the panel back off.
  - Each external is re-applied with its **live** mode rather than
    `mode="preferred"` — the Dells report no preferred mode and would drop to
    1280x720 (same trap as `monitor-docked-home.sh`). Geometry, scale and
    transform are saved to `$XDG_RUNTIME_DIR/hypr-display-mirror.state` at `on`
    and restored at `off`; with no state file it falls back to `hyprctl reload`.
    `off` does not reload by default because reload re-applies the declarative
    eDP-1 rule and would leave the panel lit while docked with the lid closed.
  - `mirror="none"` is what clears a mirror; a geometry rule alone does not
    (same shape as the `disabled=` flag needing an explicit clear).

### App Hotkeys (Super+A submap)
Modelled on Omarchy 4's `bindings/applications.lua`, merged into the existing
`Super+A` submap. Two scripts in `dotfiles/hypr/.local/share/bin/`:
- `webapp.sh <profile|email> <url>` — runs a site as a Chrome `--app=` window.
  Chrome names those windows `chrome-<host>__-<Profile_N>`, so the class
  identifies site *and* account; the script matches it in `hyprctl clients` and
  focuses the existing window instead of opening a duplicate.
- `launch-or-focus.sh <class-regex> <command>` — same behaviour for native apps
  (Signal, 1Password).

The Chrome profile is **pinned per entry** and resolved by email from
`~/.config/google-chrome/Local State` (so Chrome renumbering profiles can't
break it). This is deliberately *unlike* `browser-launcher.sh`, which picks the
profile from the active workspace — a work-calendar hotkey must open the Roche
account from any workspace. Because the profile is part of the window class, the
same site under two accounts stays two windows, each focused by its own key.

Note: `W`/`M` in this submap are WhatsApp/Maps; the vicinae system toggles that
previously held those letters moved to `Shift+`-prefixed keys.

### ASCII Logo (Omarchy)
Three scripts in `dotfiles/hypr/.local/share/bin/` for generating ASCII/Unicode
art logos (screensaver, terminal greeter, README). The first two are vendored
from basecamp/omarchy; the third is local:
- `ascii-logo-text <text>` — renders text in Delta Corps Priest 1, the FIGlet font
  the Omarchy logo is drawn in. The font is embedded in the script, so this is
  pure bash+awk with no dependencies. Letters and spaces only; digits and
  punctuation have no glyph and are named on stderr.
- `ascii-logo-image <in.svg|png> <out.txt> [--width N] [--height N]
  [--mode braille|block] [--threshold PCT] [--invert] [--no-trim]` — converts an
  image. Needs ImageMagick 7 (`magick`) + gawk, neither of which is in
  `nixos-config`, so it carries a `nix-shell -i bash --packages imagemagick gawk`
  shebang and pulls them per-run. Works because `NIX_PATH` already maps
  `nixpkgs=flake:nixpkgs`.
- `ascii-logo-fonts [text...] [--font N] [--width N] [--out F] [--list]
  [--no-omarchy]` — renders text in all 155 figlet fonts nixpkgs ships (plus the
  Omarchy font via `ascii-logo-text`), each under a `=== name ===` header, so
  you can pick one by eye. Same `nix-shell` shebang trick, for `figlet`. Written
  here, not vendored. Use it because the Omarchy font is fixed and single-case —
  `figlet` is the only way to get a *different* typeface, and the only way to get
  digits or punctuation into a text logo at all.

`braille` mode packs 2x4 pixels per cell (fine detail), `block` 1x2 (chunky, more
readable at small sizes). Clear silhouettes transcode far better than photos.

The two vendored scripts are unmodified upstream bar the shebang and the name
in `--help`. None of the three need Omarchy installed — there is no `omarchy` dispatcher here, so call the
scripts directly rather than as `omarchy ascii` / `omarchy transcode ascii`.

### Branding (ndos wordmark)
Ported from the `ndos` repo (`~/work/ndos`, branch
`claude/linux-setup-architecture-k1j16h`, commits `e76088b` + `0a81ea2`), then
reworked to use the Omarchy ASCII wordmark instead of its hand-drawn terminal
mark. Assets live in `nixos-config/branding/` — **not** the repo root, as they do
upstream, because the flake root here is `nixos-config/` and Nix cannot reach
paths outside it.

`branding/logo.txt` is the master: `ascii-logo-text NDOS`, i.e. Delta Corps
Priest 1 in Catppuccin Mocha teal, with a peach `❯`. Everything else derives
from it:
- `branding/ascii-to-svg` generates `logo.svg`. The font draws with **only**
  `█` `▀` `▄`, so every cell maps to a rectangle with no approximation —
  rasterising the SVG back to the 44x16 half-cell grid reproduces the ASCII
  pixel for pixel. Hence generated, not traced; do not hand-edit `logo.svg`.
  One cell is 1x2 user units, the aspect the font is drawn for.
- `nixos-config/branding.nix` (imported from `flake.nix`) enables Plymouth with
  the logo rendered from the SVG at build time via `rsvg-convert`, and adds
  `quiet`. It is **unconditional** — upstream gates it on `nd.branding.enable`,
  but there is no `nd.*` option namespace here, so drop the import to get the
  full text boot back.
- `branding/mk-wallpaper` regenerates
  `dotfiles/hypr/.config/hypr/wallpapers/nd.png` (mark at 10% opacity on the
  Mocha base), picked up by the existing wpaperd rotation.
- `dotfiles/fastfetch/` is the shell greeting — the wordmark with fastfetch's
  `$1`/`$2` color markers. Nothing auto-runs it; `fastfetch` was already in
  `systemPackages`.
- `hyprlock.conf` gets a dim teal `ndos ❯` **text** label, not the wordmark:
  hyprlock labels are single-line, so eight rows of ASCII do not fit.

**Render sizes must be whole multiples of the 44-cell grid** (528px for
Plymouth, 1012px for the wallpaper). Off-grid, cell edges land on fractional
pixels and rsvg antialiases visible hairline seams between the rects making up
each glyph — 512px does this. Check with a histogram: a clean render over a flat
background has exactly two colors.

### Universal Copy/Paste (ported from Omarchy 4)
`Super+C` / `Super+V` copy and paste in **every** app, so the terminal stops
being the odd one out. Implemented in the UNIVERSAL COPY/PASTE
block of `hyprland.lua`, ported from Omarchy's `bindings/clipboard.lua`:
- The chord is re-sent with `hl.dsp.send_key_state` and **no window target**, so
  it reaches layer-shell surfaces (rofi, vicinae) as well as normal windows.
  `wtype` cannot do this — the physically-held Super merges into the injected
  chord at the seat.
- Sent as a **down/up pair split by a 50ms `hl.timer`**, working around
  Hyprland leaving synthetic key state stuck/repeating (hyprwm/Hyprland#14099).
- Terminals get `Ctrl+Shift+C` / `Ctrl+Shift+V` instead, since `Ctrl+C` there is
  SIGINT. Omarchy detects terminals via its window tags; this config has none,
  so `activeWindowIsTerminal()` matches `window.class` against
  `terminalClasses` — **add new terminals to that list**.
- **Do not "restore" Omarchy's `Ctrl+Insert` / `Shift+Insert` here.** Omarchy
  ships foot; under kitty both are wrong: `ctrl+insert` is bound to nothing, so
  kitty forwards it to the running program as the xterm sequence `CSI 2;5~`
  (a stray `5~` appears in the shell), and `shift+insert` is
  `paste_from_selection` — the PRIMARY selection, not the clipboard.
  `kitty_mod` defaults to `ctrl+shift`, making `ctrl+shift+c/v` the real
  clipboard binds; the same pair is correct for ghostty, foot, alacritty and
  wezterm.
- **There is no universal cut.** Omarchy puts it on `Super+X`, but that key
  keeps its long-standing screenshot binding here (see Screen Capture below).
  Little is lost: "cut" was the one member of the trio with no terminal
  meaning, and upstream sends it with no terminal branch, so in a terminal it
  just leaks `Ctrl+X` to the running program (nano's exit, emacs' prefix).

cliphist moved to `Super+Ctrl+V` (Omarchy's slot for its clipboard manager);
the `wl-paste --watch` daemons in `exec-once` still feed it.

### Screen Capture (ported from Omarchy 4)
`Super+X` and `Print` both open the picker; the other capture modes sit on
`Print` modifiers. Scripts in `dotfiles/hypr/.local/share/bin/`:
- `capture-region.sh` — the picker, shared by screenshots and recording. Freezes
  the screen with `hyprpicker -r -z` so nothing shifts during teardown, then
  runs `slurp`. Its **"smart" mode** replaced the old three-mode split
  (`screenshot.sh sf|m|p`, deleted): drag for a freeform region, or single-click
  to snap to the window/monitor under the cursor (a click is detected as an
  area < 20px²).
- `capture-screenshot.sh` — saves to `~/obsidian/Files` as
  `YYMMDD_HHhMMmSSs_screenshot.png` **and** copies to the clipboard, then posts
  a clickable notification that opens swappy. Forces `no_hardware_cursors=0`
  around the grab, because software cursors get baked into grim's frames.
- `capture-text.sh` (OCR, tesseract) / `capture-qr.sh` (zbar). The QR result is
  `wl-copy --sensitive` — QR codes routinely carry secrets (otpauth:// URIs).
- `capture-screenrecording.sh` — gpu-screen-recorder; same picker, start/stop
  toggle. Trimmed vs upstream: **no webcam overlay, no bar indicator**.
  `programs.gpu-screen-recorder.enable` in configuration.nix is what installs
  the `cap_sys_admin` wrapper the kms backend needs — a bare systemPackages
  entry is not enough.
- `notification-send.sh` — the slice of `omarchy-notification-send` these need
  (thumbnail + clickable action), backed by `dunstify`. `dunstify -A` blocks
  while the notification is up, so the click handler is detached; without an
  action it is fire-and-forget.

For the click to do anything, `dunstrc` needs `mouse_left_click = do_action`.
Dunst's default puts `do_action` on **middle** click and gives left click
`context`, which opens a dmenu — so left-clicking a screenshot notification
just dismissed it. (`context` could never have worked here anyway: `dmenu` and
`browser` pointed at `/usr/bin/…`, which does not exist on NixOS. Both now
point at `/run/current-system/sw/bin/`.) Note dunst will not restart while
another instance holds the `org.freedesktop.Notifications` bus name — the
second one exits silently — so apply config changes with `dunstctl reload`.

While the picker is open, `hyprland.lua` registers keyboard binds scoped to
slurp's layer surface (`Enter` window, `Ctrl+Enter` fullscreen, `Tab`/arrows to
walk windows). They are **ref-counted**: slurp opens one `selection` layer *per
monitor*, so `layer.opened` fires 3× while docked; each `hl.bind` handle is
kept and `:unbind()`-ed individually on the last close. Unbinding by key would
tear same-key binds out of the rest of the config.

### cliamp (music TUI)
Winamp 2.x-styled terminal music player with built-in lo-fi radio
([cliamp.stream](https://www.cliamp.stream/)), in nixpkgs. Launched from the
`Super+A` submap on `Z` as a kitty window under its own class, so
`launch-or-focus.sh` focuses it rather than opening a second one.

Only the **theme** is stowed —
`dotfiles/cliamp/.config/cliamp/themes/catppuccin-mocha-teal.toml`. Everything
else in `~/.config/cliamp/` is deliberately unmanaged: `config.toml` is where
cliamp persists runtime state **and `[spotify] client_secret`**, so it must not
go in the repo, and the directory also holds a socket, pidfile and log. Stow
therefore links only the `themes/` subdirectory.

Because `config.toml` is unmanaged, the theme *choice* is pinned in the keybind
via `cliamp --start-theme catppuccin-mocha-teal` — that keeps it
version-controlled and reproducible on a fresh machine.

cliamp ships a built-in `catppuccin`, but it accents with Mocha blue
(`#89b4fa`); ours is the same palette re-accented to teal. A theme is exactly
six keys — `accent`, `bright_fg`, `fg`, `green`, `yellow`, `red` — each
`#RRGGBB`.

**`accent` cannot be Catppuccin's real teal `#94e2d5`.** cliamp uses `accent`
for two opposing jobs: teal *text* on the base (wants light) **and** the fill
of the footer key chips — `Esc` / `Space` / `Ctrl+K` — which it labels in
`bright_fg` (wants dark). With `#94e2d5` the chip label is `#cdd6f4` on
`#94e2d5`, i.e. **1.03:1**, and the shortcuts are invisible. Upstream's own
`#89b4fa` is only 1.46:1, so this is an upstream design weakness, not something
we introduced. We use `#389485`: 4.49:1 as text (AA), 2.53:1 for chip labels —
below 3:1 on paper but legible in practice, since light glyphs on a saturated
fill read better than the ratio suggests. Balancing both perfectly peaks at
3.37:1 each (`#2a7e6f`), which visibly dulls the teal labels. Shift `accent`
toward `#2a7e6f` for crisper chips, toward `#3fa694` for brighter labels — and
**check a real render**, not just the numbers.

**Gotcha:** cliamp treats everything after `=` as the value and validates it
against `^#[0-9a-fA-F]{6}$`, so an **inline** comment
(`accent = "#94e2d5"  # teal`) makes the whole theme fail to parse and silently
disappear from `cliamp theme list` — no error, it is just gone. Full-line
comments are fine. Verify a theme edit with `cliamp theme list` before trusting it.

### Workspace Layouts
`Super+M` runs `toggle-workspace-layout [toggle|dwindle|scrolling|status] [-q]`
in `dotfiles/hypr/.local/share/bin/`.

- **`scrolling` is built into Hyprland** (0.56 has it). It is NOT the
  `hyprscrolling` plugin, and nothing needs installing — worth stating because
  nixpkgs' `hyprlandPlugins.hyprscroller` is now a removal stub pointing at
  `hyprscrolling`, which nixpkgs does not package, and that trail wrongly
  suggests a plugin is required. `hyprctl layouts` is not a valid request, so
  there is no way to list the built-in layouts and confirm; just set one.
- Applied **per workspace** with `hl.workspace_rule({ workspace = N, layout =
  ... })`, not the global `general:layout`, so one workspace can scroll while the
  rest stay dwindle. `hyprctl activeworkspace -j` exposes the current one as
  `.tiledLayout`. Same approach as Omarchy's
  `omarchy-hyprland-workspace-layout-toggle` (their bind is `Super+L`).
- **Not persisted**: `hyprctl reload` (`Super+Shift+R`) re-runs `hyprland.lua`,
  which declares no workspace rules, so everything reverts to dwindle. Omarchy
  writes each rule into a state dir and re-sources it on reload — that is the
  piece to port if it becomes annoying.

### Launcher System
Uses `vicinae` as the primary application launcher:
- Started as server: `vicinae server` in Hyprland exec-once
- Toggle with: `vicinae toggle` (bound to Super+Space)
- Config: `dotfiles/vicinae/.config/vicinae/settings.json`
- Includes NixOS package search provider (`ns` alias)

Rofi is still used for:
- Window switcher (Super+Tab)
- File explorer (Super+Shift+E)

### Espanso (Text Expander)
Configured for text expansion with multiple match files:
- Config: `dotfiles/espanso/.config/espanso/config/default.yml`
- Match files: `base.yml`, `jacw.yml`, `roche.yml`, `private.yml`
- Includes emoji package: `actually-all-emojis-spaces`

### Neovim Configuration
Uses LazyVim as the base configuration:
- Entry point: `dotfiles/nvim/.config/nvim/init.lua`
- Bootstraps lazy.nvim plugin manager
- Configuration modules in `lua/config/` and `lua/plugins/`

### Zsh Configuration
- Managed by home-manager: shared setup in `modules/home/shell.nix`, personal aliases in `users/kraeki/home.nix`
- Uses Oh-My-Zsh with Powerlevel10k theme
- Plugins: zsh-autosuggestions, zsh-syntax-highlighting, git, per-directory-history
- Shell configuration: `.zshrc.stow` (symlinked via Stow)
- Powerlevel10k config: `.p10k.zsh`
- **z-lua**: Smart directory jumping based on frequency and recency (use `z <pattern>` to jump)
- Useful aliases:
  - `vi` → `nvim`
  - `hc` → Edit Hyprland config
  - `nc` → Edit NixOS config

### Theme System
Catppuccin Mocha with teal accent, configurable via `nd.theme.flavor` / `nd.theme.accent` in `modules/nixos/theme.nix`:
- GTK theme: `catppuccin-mocha-teal-standard`
- Icons: Colloid (teal), Numix Circle, Tela Circle Dracula
- Cursor: Catppuccin Mocha Teal
- Terminal: Ghostty with custom config (`dotfiles/ghostty/.config/ghostty/config`)

### Key Services and Daemons
Auto-started in Hyprland (`exec-once`):
- `waybar` - System bar
- `dunst` - Notifications
- `wpaperd` - Wallpaper daemon
- `vicinae server` - Launcher
- (monitors need no daemon — declarative `hl.monitor` rules + lid-switch binds; replaced kanshi)
- `cliphist` - Clipboard history (with wl-paste)
- `blueman-applet`, `nm-applet` - System tray

### Power Management
Uses power-profiles-daemon (not TLP — PPD is what AMD/Framework recommend for Ryzen 7040; TLP is explicitly disabled). Configured in `modules/nixos/power.nix`:
- Laptop-mode sysctls (batched I/O, low swappiness, NMI watchdog off)
- Zram (25%, zstd) as OOM safety net
- upower thresholds: suspend at 5% battery
- Clamshell docking: lid-close while docked does not suspend (Hyprland lid-switch binds handle the panel)
- `amd_pstate=active` kernel param lives in `hosts/naptop` (hardware-specific)
- Battery charge thresholds are set via `framework-tool`, not declaratively

## Common Keybindings

- **Super+Return**: Terminal (kitty)
- **Super+Shift+Return**: Browser (Chrome)
- **Super+Space**: Application launcher (vicinae)
- **Super+Tab**: Window switcher (rofi)
- **Super+E**: File manager (nautilus)
- **Super+Shift+E**: File explorer (rofi)
- **Super+Q**: Close window
- **Super+F**: Fullscreen
- **Super+T**: Toggle floating on the focused window (`Super+Ctrl+Space` is an alias)
- **Super+C / Super+V**: Universal copy / paste (see below)
- **Super+Ctrl+V**: Clipboard history (rofi + cliphist)
- **Super+X** / **Print**: Screenshot — smart picker (see below)
- **Alt+Print**: Screen recording (start / stop toggle)
- **Super+Print**: Color picker (hyprpicker)
- **Super+Ctrl+Print**: Extract text from a region (OCR)
- **Super+Shift+Print**: Decode a QR code from a region
- **Super+M**: Toggle the active workspace between dwindle and scrolling layout
- **Super+Backspace**: Toggle the laptop panel on/off (`toggle-laptop-display`)
- **Super+Ctrl+Backspace**: Toggle presentation mirroring (`toggle-display-mirror`)
  - Backspace, not Delete: the Magic Keyboard's `delete` key emits KEY_BACKSPACE
    (real Delete is fn+delete there). Physically these are Ctrl+delete and
    Ctrl+Option+delete — see the modifier-rotation note under Important Notes.
  - These keys previously held the session-exit binds; both were removed
    (`Super+Delete` = `hl.dsp.exit()`, too easy to hit by accident;
    `Super+Backspace` = `$srcPath/logoutlaunch.sh`, a script that has never
    existed in this repo — the bind was silently dead). There is now **no logout
    keybind**, and no `wlogout` installed; log out with `loginctl`.
- **Super+A**: App / selector submap (launch-or-focus; second press focuses, never duplicates)
  - `Y` YouTube · `W` WhatsApp · `T` Telegram · `P` Photos · `M` Maps (private Chrome profile)
  - `C` Calendar · `G` Gmail · `D` Drive (Roche work Chrome profile)
  - `S` Signal · `/` 1Password (native apps)
  - `Z` cliamp, the Winamp-styled music TUI (kitty under its own class)
  - `Shift+W` wifi · `Shift+A` audio · `Shift+B` bluetooth · `Shift+M` calendar agenda (vicinae)
- **Super+J**: Toggle split of focused window, horizontal ↔ vertical (`Super+N` is an alias)
- **Super+Escape**: Lock screen (hyprlock)

## Docker

Docker is enabled and the user is in the docker group. Use standard docker commands without sudo.

## Important Notes

- The NixOS configuration enables flakes and nix-command experimental features
- System uses systemd-boot and latest kernel (`linuxPackages_latest`)
- Keyboard layouts: US and CH (Swiss) with Both Shifts to toggle
- Keyboard remapping (`kb_options = "caps:super,altwin:ctrl_alt_win,..."`): Caps
  Lock → Super, and `altwin:ctrl_alt_win` **rotates** the other three (it is NOT
  a Ctrl↔Alt swap). What a bind name means physically:
  | bind says | you press |
  |---|---|
  | `SUPER` | physical Ctrl (or Caps Lock) |
  | `CTRL`  | physical Alt / Option |
  | `ALT`   | physical Win / Cmd |
  This is also why the right-hand Option key emits `Control_R` (`code:108`, the
  dictation bind) rather than Super.
- Monitor scaling: GDK_SCALE=1.333 for HiDPI display
- Scripts directory must exist at `~/.local/share/bin/` for Hyprland to function properly
- 1Password requires gnome-keyring (configured in system)
- The main keyboard is an **Apple Magic Keyboard with Touch ID**, which has no
  forward-Delete key: the key labelled `delete` sends KEY_BACKSPACE, and
  KEY_DELETE is only reachable as fn+delete. Binds on `Delete` therefore look
  dead on it while working on the Framework's built-in keyboard — prefer
  `Backspace` for anything meant to work on both.
