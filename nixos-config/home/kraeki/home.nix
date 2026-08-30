{ config, pkgs, inputs, ... }:

let
  # herdr: terminal agent-multiplexer (github.com/herdrdev/herdr).
  # Not in nixpkgs; upstream ships a prebuilt Linux binary that we patchelf
  # onto the NixOS dynamic loader. Bump `version` + `hash` on updates
  # (nix store prefetch-file <url>).
  herdr = pkgs.stdenv.mkDerivation rec {
    pname = "herdr";
    version = "0.8.2";
    src = pkgs.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-linux-x86_64";
      hash = "sha256-l2FQoU1JDJSyQ+ouGn6y37Z/EuNrGC25CTb2co5q7PQ=";
    };
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/herdr
      runHook postInstall
    '';
    meta = with pkgs.lib; {
      description = "Terminal multiplexer / agent multiplexer for AI coding agents";
      homepage = "https://herdr.dev/";
      platforms = [ "x86_64-linux" ];
    };
  };

  # tldraw offline (github.com/tldraw/tldraw-offline): a local, file-based
  # infinite-canvas whiteboard desktop app (Electron). No account/server, boards
  # live in .tldraw files on disk. Shipped only as a GitHub-release AppImage, so
  # wrap it with appimageTools to get a real `tldraw-offline` binary plus the
  # bundled .desktop/icons on NixOS. Bump `version` + `hash` on updates
  # (nix store prefetch-file <url>).
  tldraw-offline = let
    version = "1.11.0";
    src = pkgs.fetchurl {
      url = "https://github.com/tldraw/tldraw-offline/releases/download/v${version}/tldraw-offline-linux-x86_64.AppImage";
      hash = "sha256-CUkGdHYz22gOYV5X+yAdB4yWi1Ii5zHJ53qgdnNEDgU=";
    };
    appimageContents = pkgs.appimageTools.extractType2 {
      pname = "tldraw-offline";
      inherit version src;
    };
  in pkgs.appimageTools.wrapType2 {
    pname = "tldraw-offline";
    inherit version src;
    # Bundle the AppImage's own launcher entry + icons, and point Exec at the
    # wrapped binary (upstream ships Exec=AppRun --no-sandbox %U).
    extraInstallCommands = ''
      install -Dm444 ${appimageContents}/@tldesktop.desktop \
        $out/share/applications/tldraw-offline.desktop
      cp -r ${appimageContents}/usr/share/icons $out/share/
      substituteInPlace $out/share/applications/tldraw-offline.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=tldraw-offline'
    '';
  };
in

{
  home.username = "kraeki";
  home.homeDirectory = "/home/kraeki";
  home.stateVersion = "23.11";

  # `uv tool install <pkg>` drops standalone shims here (they embed their own
  # venv python, so uv itself isn't needed at runtime). Holds the `graphify`
  # knowledge-graph CLI backing the /graphify Claude Code skill.
  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;

    shellAliases = {
      vi = "nvim";
      hc = "vi ~/.config/hypr";
      nc = "cd ~/work/nd-dotfiles/nixos-config; vi ./hosts/naptop/configuration.nix";
      # Always start Claude Code in bypass-permissions mode.
      # ~/.claude/settings.json already sets skipDangerousModePermissionPrompt,
      # so this starts straight into the session without the confirmation screen.
      claude = "claude --dangerously-skip-permissions";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "per-directory-history" ]; 
      theme = ""; 
    };

    plugins = [
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
      }
    ];

    initContent = ''
      # Powerlevel10k initialisieren
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

      # z-lua initialization
      eval "$(${pkgs.z-lua}/bin/z --init zsh enhanced once)"

      # npm global packages
      export PATH="$HOME/.npm-global/bin:$PATH"
    '';
  };

  # Fuzzy finder with zsh integration (Ctrl-R history, Ctrl-T files, Alt-C cd).
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
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
    tldraw-offline   # Local file-based whiteboard (AppImage, defined in let block)
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
                     # Currently provides: graphify (see home.sessionPath below).
    glib             # Provides gio trash command
    ast-grep         # Structural search/replace
    ghostscript      # PDF rendering in neovim
    chafa            # Image preview in terminal/fzf

    # Shell utilities
    z-lua
    tealdeer         # Fast tldr client (provides the `tldr` command)
    herdr            # Terminal agent-multiplexer (prebuilt, defined in let block)

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
    # x86_64 build for the pinned rev (see flake.nix / configuration.nix).
    inputs.handy.packages.${pkgs.system}.default

    # Misc
    teamviewer

    firefox
  ];

  programs.google-chrome = {
    enable = true;
    # Patch RUNPATH so the sandboxed GPU process can find libEGL.so.1 / libGL.so.1
    # via /run/opengl-driver/lib. Chrome's sandbox strips LD_LIBRARY_PATH from the
    # wrapper, so RUNPATH is the only way these libs reach the GPU process.
    package = pkgs.google-chrome.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        ${pkgs.patchelf}/bin/patchelf \
          --add-rpath /run/opengl-driver/lib \
          $out/share/google/chrome/chrome
      '';
    });
    commandLineArgs = [
      "--ozone-platform=wayland"
      # Store cookie/password encryption key via libsecret (gnome-keyring) directly.
      # Without this, Wayland Chrome tries the org.freedesktop.portal.Secret portal,
      # which isn't served in this Hyprland session (portals.conf routes only
      # hyprland;gtk, neither of which provides Secret). Init then fails, no stable
      # key is stored, Google session cookies can't persist across restarts, and
      # Workspace accounts (e.g. ajv.ch) endlessly prompt "verify it's you".
      "--password-store=gnome-libsecret"
      "--use-gl=angle"
      "--use-angle=vulkan"
      "--enable-gpu-rasterization"
      "--disable-zero-copy"
      "--ignore-gpu-blocklist"
      "--enable-features=Vulkan,VulkanFromANGLE,DefaultANGLEVulkan,AcceleratedVideoDecodeLinuxGL,VaapiIgnoreDriverChecks,IntensiveWakeUpThrottling:grace_period_seconds/10,InfiniteTabsFreezing,MemoryPurgeOnFreeze"
    ];
  };

  services.syncthing = {
     enable = true;
   };
}
