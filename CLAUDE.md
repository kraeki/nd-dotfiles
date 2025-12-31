# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for a NixOS system with Hyprland window manager. It uses GNU Stow for managing dotfiles and NixOS flakes for system configuration.

## Repository Structure

The repository has two main configuration approaches:

### 1. Stow-Managed Dotfiles
Application-specific dotfiles organized in the `dotfiles/` subdirectory (e.g., `dotfiles/hypr/`, `dotfiles/nvim/`, `dotfiles/waybar/`). Each directory contains the `.config/` hierarchy that gets symlinked to `$HOME` via Stow.

### 2. NixOS Configuration
The `nixos-config/` directory at repository root contains:
- `flake.nix` - NixOS flake configuration for host "naptop"
- `hosts/naptop/configuration.nix` - System-level packages and services
- `home/kraeki/home.nix` - User-level packages managed by home-manager
- `theme.nix` - Catppuccin Mocha theme configuration

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
# Rebuild and switch to new NixOS configuration
cd nixos-config
sudo nixos-rebuild switch --flake .#naptop

# Test configuration without switching
sudo nixos-rebuild test --flake .#naptop

# Build configuration without activating
sudo nixos-rebuild build --flake .#naptop
```

### Flakes
```bash
# Update all flake inputs
cd nixos-config
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs
```

## Key Architecture Details

### Package Management Split
- **System packages** (`environment.systemPackages` in `configuration.nix`): Core system tools, desktop environment components, CLI utilities
- **User packages** (`home.packages` in `home.nix`): GUI applications, productivity tools, entertainment software

This separation keeps system concerns distinct from user preferences and makes home-manager configuration portable.

### Hyprland Configuration
- Main config: `dotfiles/hypr/.config/hypr/hyprland.conf`
- Modular structure using `source` statements:
  - `keybindings.conf` - Keyboard shortcuts
  - `windowrules.conf` - Window behavior rules
  - `animations.conf` - Animation settings
  - `themes/*.conf` - Theme and color settings
  - `monitors.conf` - User-specific monitor config (static)
  - `userprefs.conf` - User-specific overrides (static, sourced last)
- Scripts location: `~/.local/share/bin/` (referenced as `$srcPath` in config)
- Monitor management scripts: `dotfiles/hypr/.config/hypr/bin/monitor-*.sh`

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
- Managed by home-manager in `home.nix`
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
Catppuccin Mocha with teal accent:
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
- `kanshi` - Monitor management
- `cliphist` - Clipboard history (with wl-paste)
- `blueman-applet`, `nm-applet` - System tray

### Power Management
Uses TLP (not power-profiles-daemon) with aggressive battery optimization:
- USB autosuspend enabled
- PCIe ASPM: powersupersave on battery
- SATA ALPM: min_power on battery
- CPU governor: powersave on battery with boost disabled
- Battery charge thresholds: 75-80%
- Platform profile: low-power on battery

## Common Keybindings

- **Super+Return**: Terminal (kitty)
- **Super+Shift+Return**: Browser (Chrome)
- **Super+Space**: Application launcher (vicinae)
- **Super+Tab**: Window switcher (rofi)
- **Super+E**: File manager (nautilus)
- **Super+Shift+E**: File explorer (rofi)
- **Super+Q**: Close window
- **Super+F**: Fullscreen
- **Super+X**: Screenshot (selection)
- **Print**: Screenshot (all monitors)
- **Super+M**: Toggle laptop-only monitor mode
- **Super+A**: AI assistant shortcut
- **Super+Escape**: Lock screen (hyprlock)

## Docker

Docker is enabled and the user is in the docker group. Use standard docker commands without sudo.

## Important Notes

- The NixOS configuration enables flakes and nix-command experimental features
- System uses systemd-boot and latest kernel (`linuxPackages_latest`)
- Keyboard layouts: US and CH (Swiss) with Both Shifts to toggle
- Keyboard remapping: Caps Lock → Super, Ctrl ↔ Alt
- Monitor scaling: GDK_SCALE=1.333 for HiDPI display
- Scripts directory must exist at `~/.local/share/bin/` for Hyprland to function properly
- 1Password requires gnome-keyring (configured in system)
