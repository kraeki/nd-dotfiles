{ config, pkgs, ... }:

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

  home.packages = with pkgs; [
    # Productivity & Communication
    obsidian
    _1password-gui
    seahorse
    slack
    claude-code
    codex
    gemini-cli

    # Google Drive Sync
    rclone
    syncthing

    # Creative
    audacity
    inkscape
    gimp
    davinci-resolve-studio
    shotcut

    # Entertainment
    steam
    protontricks
    mplayer

    # Development tools
    lazygit          # TUI for git (LazyVim integration)
    python3          # Python runtime for LSPs and tools
    glib             # Provides gio trash command
    ast-grep         # Structural search/replace
    ghostscript      # PDF rendering in neovim
    chafa            # Image preview in terminal/fzf

    # Shell utilities
    z-lua

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
