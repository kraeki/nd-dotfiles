# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  #boot.kernelPackages = pkgs.linuxPackages_6_15;

  boot.kernelModules = [ "hid_apple" ];
  boot.extraModprobeConfig = ''
    options hid_apple swap_fn_leftctrl=1 swap_opt_cmd=1 fnmode=2
  '';

  networking.hostName = "naptop"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable bluethooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kraeki = {
    isNormalUser = true;
    description = "Andreas Schmid";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.zsh;
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  # FIMXE: Due to Ulauncher 
  nixpkgs.config.permittedInsecurePackages = [
    "libsoup-2.74.3"
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    htop
    vim
    fd
    usbutils
    # neovim 
    neovim
    fzf
    clang
    ripgrep
    tree-sitter
    # -- neovim 
    git
    tig
    gnumake
    hyprland
    dunst
    bc
    brightnessctl
    upower
    libnotify
    jq # used by hyprland scripts
    wpaperd # wallpaper daemon
    hyprlock
    kitty
    waybar
    lm_sensors # used by cpuinfo / waybar
    zsh
    zsh-powerlevel10k
    oh-my-zsh
    rofi
    pulseaudio
    bluez
    kanshi
    thunderbolt # enabling docking station (tbtadm)
    neofetch
    nautilus
    swappy
    grim
    slurp
    stow
    poppler-utils #pdfunite
    vicinae # - launcher

    obsidian
    seahorse
    _1password-gui
    wget
    curl
    docker
    audacity
    inkscape
    gimp
    google-chrome

    steam
    protontricks

    slack

    # My Launcher
    wl-clipboard
    cliphist        

    claude-code
    gemini-cli

    unzip
    networkmanagerapplet  

    mplayer
    teamviewer
    claude-code

    nodejs_22 # to have npm / e.g nvim/mason requires it
    tcpdump

    file
    whois
  ];

  programs.nano.enable = false;
  services.hardware.bolt.enable = true;

  services.teamviewer.enable = true;
  services.power-profiles-daemon.enable = true;



  ## 1password needs keyring 
  services.gnome.gnome-keyring.enable = true;

  ## Steam 
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;  # Optional: only if you plan to use Remote Play
    dedicatedServer.openFirewall = false;  # Optional
  };
  
  hardware.graphics.enable32Bit = true; # Required for 32-bit games
  hardware.steam-hardware.enable = true;  # Enables udev rules for game controllers
  ## - Steam

  programs.hyprland.enable = true; 
  programs.zsh.enable = true; 

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  services.blueman.enable = true;
  services.upower.enable = true;

  virtualisation.docker.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    secret-key-files = ["/etc/nix/signing-key.sec"];
  };
}
