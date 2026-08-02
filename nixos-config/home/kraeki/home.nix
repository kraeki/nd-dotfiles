{ config, pkgs, inputs, ... }:

let
  # herdr: terminal agent-multiplexer (github.com/ogulcancelik/herdr).
  # Not in nixpkgs; upstream ships a prebuilt Linux binary that we patchelf
  # onto the NixOS dynamic loader. Bump `version` + `hash` on updates
  # (nix store prefetch-file <url>).
  herdr = pkgs.stdenv.mkDerivation rec {
    pname = "herdr";
    version = "0.7.4";
    src = pkgs.fetchurl {
      url = "https://github.com/ogulcancelik/herdr/releases/download/v${version}/herdr-linux-x86_64";
      hash = "sha256-vA/ALUulAPnKwjU6Q+Z/4DZ4Xsym61U3jgUPrDwQMFk=";
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

  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;

    shellAliases = {
      vi = "nvim";
      hc = "vi ~/.config/hypr";
      nc = "cd ~/work/nd-dotfiles/nixos-config; vi ./hosts/naptop/configuration.nix";
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

    # Development tools
    lazygit          # TUI for git (LazyVim integration)
    lazydocker       # TUI for docker
    superfile        # TUI file manager (`spf`)
    python3          # Python runtime for LSPs and tools
    glib             # Provides gio trash command
    ast-grep         # Structural search/replace
    ghostscript      # PDF rendering in neovim
    chafa            # Image preview in terminal/fzf

    # Shell utilities
    z-lua
    tealdeer         # Fast tldr client (provides the `tldr` command)
    herdr            # Terminal agent-multiplexer (prebuilt, defined in let block)

    # Screen annotation (Wayland/Hyprland, layer-shell) — upstream flake
    inputs.wayscriber.packages.${pkgs.system}.default

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
