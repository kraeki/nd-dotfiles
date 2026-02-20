# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, home-manager, hyprdynamicmonitors, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      home-manager.nixosModules.home-manager
    ];


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  #boot.kernelPackages = pkgs.linuxPackages_6_15;

  # AMD pstate driver for optimal power management on Ryzen 7040
  # active mode enables EPP (Energy Performance Preference) for PPD control
  boot.kernelParams = [
    "amd_pstate=active"
    "amdgpu.dcdebugmask=0x10"  # Fix video freezes on Framework AMD
  ];

  boot.kernelModules = [ "hid_apple" "wireguard" ];
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

  # AMD CPU microcode updates for stability and security
  hardware.cpu.amd.updateMicrocode = true;

  # Kernel power management parameters (ArchWiki recommendations)
  boot.kernel.sysctl = {
    "kernel.nmi_watchdog" = 0;           # Disable NMI watchdog to reduce power consumption
    "vm.dirty_writeback_centisecs" = 6000;  # Aggregate disk I/O (60s vs default 5s)
    "vm.laptop_mode" = 5;                # Batch I/O operations for better power efficiency
  };

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

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.kraeki = import ../../home/kraeki/home.nix;
  };

  # Wayland for Chromium-family apps (Chrome/Electron) on NixOS
  environment.sessionVariables.NIXOS_OZONE_WL = "1";  # :contentReference[oaicite:2]{index=2}
  # List packages installed in system profile.
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
    bc
    upower
    libnotify
    jq
    lm_sensors
    stow
    wget
    curl
    docker
    unzip
    file
    whois
    tcpdump
    dnsmasq
    nodejs_22
    tor
    wireguard-tools
    tmux
    glow
    gh
    hyprdynamicmonitors.packages.${pkgs.system}.default

    # Desktop environment
    hyprland
    dunst
    wpaperd
    hyprlock
    kitty
    waybar
    rofi
    kanshi
    nautilus
    networkmanagerapplet
    hyprpicker

    # Hardware & Power
    brightnessctl
    pulseaudio
    bluez
    thunderbolt
    powertop

    # Shell
    zsh
    zsh-powerlevel10k
    oh-my-zsh
    neofetch

    # Clipboard & Screenshot
    wl-clipboard
    cliphist
    swappy
    grim
    slurp

    # Utilities
    poppler-utils # for pdfunite
    vicinae      # launcher

    # Neovim & dependencies
    neovim
    fzf
    clang
    ripgrep
    tree-sitter
  ];

  # programs.nano.enable = false;
  services.hardware.bolt.enable = true;

  services.teamviewer.enable = true;

  ## Power Management
  # Use power-profiles-daemon as recommended by AMD and Framework for Ryzen 7040
  services.power-profiles-daemon.enable = true;
  powerManagement.powertop.enable = true;

  # TLP conflicts with power-profiles-daemon and is not recommended for AMD Ryzen 7040
  services.tlp.enable = false;

  # Battery charge thresholds (Framework specific)
  # Note: These need framework-tool or manual sysfs writes to persist
  # Consider using systemd-tmpfiles or udev rules for this


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
  services.tailscale.enable = true;
  networking.firewall.checkReversePath = "loose";
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Require SSH keys
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no"; # Security best practice
    };
    # Only open SSH to your Tailscale network for maximum security
    openFirewall = false; 
  };

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
