# Core system layer: nix itself, the base CLI toolbox, zsh, editors.
{ config, lib, pkgs, ... }:

{
  options.nd.core.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "Nix settings (flakes, gc), base CLI tools, zsh, and neovim.";
  };

  config = lib.mkIf config.nd.core.enable {
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # Handy speech-to-text binary cache. extra-* so cache.nixos.org is kept.
      # NOTE: upstream's cache currently has no x86_64 build for our pinned rev, so
      # this is a no-op today (first build compiles from source — see flake.nix).
      # Kept configured so future Handy revs that ARE cached download prebuilt
      # instead of recompiling ~1100 Rust crates.
      extra-substituters = [ "https://handy-computer.cachix.org" ];
      extra-trusted-public-keys = [
        "handy-computer.cachix.org-1:Sihzctn6DC0CJM5QeL+9nBEL3CL8c33m777C+eIv748="
      ];
    };

    # Auto garbage-collect old generations weekly
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    # Enable all SysRq functions for emergency recovery (REISUB)
    boot.kernel.sysctl."kernel.sysrq" = 1;

    services.timesyncd.enable = true;

    programs.zsh.enable = true;

    environment.systemPackages = with pkgs; [
      # System tools
      lsof
      htop
      vim
      fd
      usbutils
      git
      tig
      gnumake
      cmake
      bc
      upower
      libnotify
      jq
      lm_sensors
      stow
      wget
      curl
      unzip
      file
      whois
      dig
      tcpdump
      dnsmasq
      nodejs_22
      tor
      wireguard-tools
      tmux
      glow
      gh

      # Shell
      zsh
      zsh-powerlevel10k
      oh-my-zsh
      fastfetch

      # Neovim & dependencies
      neovim
      fzf
      clang
      ripgrep
      tree-sitter
    ];
  };
}
