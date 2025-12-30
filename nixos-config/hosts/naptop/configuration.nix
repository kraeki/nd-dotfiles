# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, home-manager, ... }:

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

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.kraeki = import ../../home/kraeki/home.nix;
  };

  # FIMXE: Due to Ulauncher 
  nixpkgs.config.permittedInsecurePackages = [
    "libsoup-2.74.3"
  ];

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    # System tools
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

  programs.nano.enable = false;
  services.hardware.bolt.enable = true;

  services.teamviewer.enable = true;

  ## Power Management
  services.power-profiles-daemon.enable = false;
  powerManagement.powertop.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      # USB-Autosuspend
      USB_AUTOSUSPEND = "1";                # USB-Geräte im Leerlauf automatisch aussetzen
      # PCIe Active-State Power Management (ASPM)
      PCIE_ASPM_ON_AC = "default";          # ASPM gemäß Systemeinstellung auf Netzstrom
      PCIE_ASPM_ON_BAT = "powersupersave";  # Maximales ASPM auf Akku für minimale Link-Leistungsaufnahme
      # SATA Link Power Management (ALPM)
      SATA_LINKPWR_ON_AC = "med_power_with_dipm";  # Moderate Stromsparstufe auf Netzstrom (Standard)
      SATA_LINKPWR_ON_BAT = "min_power";          # Aggressivste Stromsparstufe auf Akku (max. Energiesparen)
      # CPU: Governor und Boost
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";   # Energiesparender CPU-Governor auf Akku
      CPU_BOOST_ON_BAT = "0";                     # CPU-Turbo/Boost auf Akku deaktivieren (0 = aus) 
      CPU_BOOST_ON_AC = "1";                      # (zum Vergleich: Boost auf Netzstrom erlauben)
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";    # (Falls unterstützt) EPP auf maximale Energieeffizienz setzen
      # WLAN, Bluetooth und Netzwerk
      WIFI_PWR_ON_BAT = "on";                     # WLAN-Stromsparmodus auf Akku aktivieren
      WOL_DISABLE = "Y";                          # Wake-on-LAN deaktivieren (Y) 
      DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = "bluetooth wifi wwan";  # Funkgeräte bei Nichtbenutzung auf Akku ausschalten
      # Audio-Powermanagement
      SOUND_POWER_SAVE_ON_AC = "1";               # Audio-Powerdown nach 1s Inaktivität (Netzstrom)
      SOUND_POWER_SAVE_ON_BAT = "1";              # Audio-Powerdown nach 1s Inaktivität (Akku)
      SOUND_POWER_SAVE_CONTROLLER = "Y";          # Audio-Controller mit ausschalten
      # Optionale Ladegrenzwerte (wenn vom Gerät unterstützt)
      START_CHARGE_THRESH_BAT0 = "75";            # Untere Ladeschwelle 75%
      STOP_CHARGE_THRESH_BAT0 = "80";             # Obere Ladeschwelle 80%
      # (Optional) Plattform-Profil
      PLATFORM_PROFILE_ON_AC = "balanced";        # Ausgewogenes Profil am Netz
      PLATFORM_PROFILE_ON_BAT = "low-power";      # Energiespar-Profil auf Akku
      # Grafik/Display
      RADEON_DPM_PERF_LEVEL_ON_AC = "auto";       # GPU Performance-Level automatisch (Netz)
      RADEON_DPM_PERF_LEVEL_ON_BAT = "low";       # GPU in niedrigsten Performance-State auf Akku
    };
  };


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
