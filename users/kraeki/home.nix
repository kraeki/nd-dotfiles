# kraeki's home: the nd home profile plus personal packages and aliases.
{ config, pkgs, inputs, ... }:

let
  herdr = pkgs.callPackage ../../pkgs/herdr.nix { };
  tldraw-offline = pkgs.callPackage ../../pkgs/tldraw-offline.nix { };
in
{
  imports = [ ../../modules/home ];

  # The nd home profile (modules/home), whole thing on.
  nd.enable = true;

  home.username = "kraeki";
  home.homeDirectory = "/home/kraeki";
  home.stateVersion = "23.11";

  # `uv tool install <pkg>` drops standalone shims here (they embed their own
  # venv python, so uv itself isn't needed at runtime). Holds the `graphify`
  # knowledge-graph CLI backing the /graphify Claude Code skill.
  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.home-manager.enable = true;

  # Personal aliases (merge into the nd shell profile's zsh config)
  programs.zsh.shellAliases = {
    vi = "nvim";
    hc = "vi ~/.config/hypr";
    nc = "cd ~/work/nd-dotfiles; vi ./hosts/naptop/default.nix";
    # Always start Claude Code in bypass-permissions mode.
    # ~/.claude/settings.json already sets skipDangerousModePermissionPrompt,
    # so this starts straight into the session without the confirmation screen.
    # Named `c` rather than shadowing `claude`, so the bare command still
    # runs with normal permission prompts when that is what you want.
    c = "claude --dangerously-skip-permissions";
  };

  home.packages = with pkgs; [
    # Productivity & Communication
    obsidian
    _1password-gui
    signal-desktop
    seahorse
    slack
    claude-code
    codex
    gemini-cli

    # Runs AppImages on NixOS (patches loader paths, provides FHS + FUSE).
    # e.g. `appimage-run ~/Downloads/VibeTyper.AppImage`
    appimage-run

    # Google Drive Sync
    rclone
    syncthing

    # Creative
    audacity
    inkscape
    gimp
    tldraw-offline   # Local file-based whiteboard (AppImage, see pkgs/)
    davinci-resolve-studio
    shotcut

    # Entertainment
    steam
    protontricks
    mplayer
    cliamp           # Winamp 2.x-styled terminal music player + lo-fi radio
                     # (cliamp.stream). Super+A then Z; "?" for its keys.

    # Development tools
    lazygit          # TUI for git (LazyVim integration)
    lazydocker       # TUI for docker
    superfile        # TUI file manager (`spf`)
    python3          # Python runtime for LSPs and tools
    uv               # Python package/tool manager; installs PyPI CLIs that
                     # aren't in nixpkgs into ~/.local/bin (`uv tool install`).
                     # Currently provides: graphify (see home.sessionPath above).
    glib             # Provides gio trash command
    ast-grep         # Structural search/replace
    ghostscript      # PDF rendering in neovim
    chafa            # Image preview in terminal/fzf

    # Shell utilities
    tealdeer         # Fast tldr client (provides the `tldr` command)
    herdr            # Terminal agent-multiplexer (prebuilt, see pkgs/)

    # Screen annotation (Wayland/Hyprland, layer-shell) — upstream flake.
    # doCheck disabled: wayscriber runs its Rust test suite at build time, and a
    # handful of tests (font_picker ordering, daemon_v1 fixtures) are sensitive
    # to the sandbox's font set / toolchain. They pass upstream but fail inside
    # Nix's hermetic build whenever nixpkgs moves, which would block the entire
    # system build on a nixpkgs bump. The runtime binary is unaffected. (2026-08-28)
    (inputs.wayscriber.packages.${pkgs.system}.default.overrideAttrs (_: {
      doCheck = false;
    }))

    # Handy: offline push-to-talk speech-to-text (Whisper GPU / Parakeet CPU),
    # types transcription into the focused field. Runs alongside VoiceFlow (which
    # stays on the right-cmd key) — Handy is autostarted via hyprland.lua
    # exec-once and toggled with F5 (`handy --toggle-transcription`). Wayland text
    # injection uses wtype (already in systemPackages). NOTE: first build
    # compiles from source (~1100 Rust crates) — upstream's cachix cache has no
    # x86_64 build for the pinned rev (see flake.nix / modules/nixos/core.nix).
    inputs.handy.packages.${pkgs.system}.default

    # Misc
    teamviewer

    firefox
  ];

  services.syncthing = {
     enable = true;
   };
}
