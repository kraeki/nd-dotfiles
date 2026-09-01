# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, home-manager, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      home-manager.nixosModules.home-manager
    ];


  # Waybar: pin to the upstream fix for Hyprland 0.54+ Lua IPC dispatch.
  # 0.15.0 sends the legacy text command "dispatch workspace N" over the
  # socket, which Hyprland now parses as invalid Lua, silently breaking
  # workspace clicks and scroll in the bar. Commit e17c0d9f adds protocol
  # auto-detection (hl.dsp.* on Lua-IPC Hyprland, legacy text otherwise).
  # Remove this override once nixpkgs ships waybar > 0.15.0 with the fix.
  nixpkgs.overlays = [
    (final: prev: {
      waybar = prev.waybar.overrideAttrs (old: {
        version = "0.15.0-unstable-2026-04-29";
        src = prev.fetchFromGitHub {
          owner = "Alexays";
          repo = "Waybar";
          rev = "e17c0d9f0a73acc370df60ec8c532b1ed2385c73";
          hash = "sha256-p5iqMo4JPhbukRqPlYjciaU89wRPDmWSUY9NkxywI+k=";
        };
        # This post-0.15.0 source renamed the cava meson subproject, so the
        # nixpkgs cava vendoring no longer matches. The bar uses no cava module,
        # so disable it rather than chase the new subproject layout.
        mesonFlags = (builtins.filter (f: f != "-Dcava=enabled") old.mesonFlags)
          ++ [ "-Dcava=disabled" ];
        # Upstream never bumped the in-binary version past 0.15.0 on this commit,
        # so the version-check hook would reject our descriptive version string.
        doInstallCheck = false;
      });
    })
  ];


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # LTS kernel - more stable amdgpu driver (6.19.8 had slab allocator crashes)
  boot.kernelPackages = pkgs.linuxPackages;
  #boot.kernelPackages = pkgs.linuxPackages_latest;

  # AMD pstate driver for optimal power management on Ryzen 7040
  # active mode enables EPP (Energy Performance Preference) for PPD control
  boot.kernelParams = [
    "amd_pstate=active"
    "amdgpu.dcdebugmask=0x10"  # Fix video freezes on Framework AMD
    "amdgpu.gpu_recovery=1"    # Auto-reset GPU on hang instead of freezing system
  ];

  # Encrypted swap (nvme0n1p3) + hibernation.
  #
  # hardware-configuration.nix declares this partition as a swapDevice by its
  # mapper path, but nothing ever unlocked the container -- only the root volume
  # had an initrd.luks entry. systemd therefore waited out its full 90s device
  # timeout on every boot ("A start job is running for /dev/mapper/luks-ce375174-...")
  # before failing swap.target. That 90s *was* the boot delay.
  #
  # No second passphrase prompt, *provided both volumes share a passphrase*.
  # This is a systemd initrd (boot.initrd.systemd.enable is true here), so the
  # two devices land in the initrd's /etc/crypttab and systemd-cryptsetup caches
  # the entered passphrase in the kernel keyring -- crypttab's password-cache=
  # defaults to "yes", and the cache is checked before prompting again. The 2.5
  # minute cache timeout is irrelevant since both unlock back-to-back.
  # NB: boot.initrd.luks.reusePassphrases does NOT apply -- that is the
  # script-based initrd's mechanism and is dead code on this system.
  # If the passphrases ever diverge, add the root key to this volume with
  # `cryptsetup luksAddKey`; do not reach for an initrd keyfile, which would sit
  # on the unencrypted /boot.
  boot.initrd.luks.devices."luks-ce375174-c66d-4587-bf7c-acf70aa63c2f".device =
    "/dev/disk/by-uuid/ce375174-c66d-4587-bf7c-acf70aa63c2f";

  # Hibernation. 33.7G of swap against 30G of RAM, so the image fits. This only
  # works because the device above is opened in initrd, before resume runs.
  # zramSwap stays at priority 5, so it is still filled first and the disk swap
  # remains the deeper safety net.
  boot.resumeDevice = "/dev/mapper/luks-ce375174-c66d-4587-bf7c-acf70aa63c2f";

  boot.kernelModules = [ "hid_apple" "wireguard" ];
  boot.extraModprobeConfig = ''
    options hid_apple swap_fn_leftctrl=1 swap_opt_cmd=1 fnmode=2
    # Disable USB autosuspend on the MediaTek (0e8d:e616) Bluetooth radio.
    # btusb autosuspend (default Y) powers down the controller after idle and
    # this chip doesn't reliably wake on a peripheral reconnect, so the BT
    # mouse fails to reconnect after long idle.
    options btusb enable_autosuspend=0
  '';

  networking.hostName = "naptop"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  networking.networkmanager.settings.connectivity = {
    uri = "http://nmcheck.gnome.org/check_network_status.txt";
    interval = 300;
  };

  # DNS resolution - systemd-resolved handles split DNS properly:
  # WiFi DNS for general queries, Tailscale MagicDNS for .ts.net only.
  # Fixes: DNS failure after sleep (no more sole dependency on Tailscale DNS)
  # Fixes: Captive portal detection (WiFi DNS is reachable for connectivity checks)
  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [ "1.1.1.1" "8.8.8.8" ];
  };

  # Enable bluethooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # AMD CPU microcode updates for stability and security
  hardware.cpu.amd.updateMicrocode = true;

  # Kernel power management parameters (ArchWiki recommendations)
  boot.kernel.sysctl = {
    "kernel.sysrq" = 1;                    # Enable all SysRq functions for emergency recovery (REISUB)
    "kernel.nmi_watchdog" = 0;           # Disable NMI watchdog to reduce power consumption
    "vm.dirty_writeback_centisecs" = 6000;  # Aggregate disk I/O (60s vs default 5s)
    "vm.laptop_mode" = 5;                # Batch I/O operations for better power efficiency
    "vm.swappiness" = 10;               # Prefer RAM, use zram only as safety net
    "vm.vfs_cache_pressure" = 50;       # Keep more filesystem metadata cached (32GB RAM)
  };

  # Zram: compressed in-RAM swap as OOM safety net
  zramSwap = {
    enable = true;
    memoryPercent = 25;
    algorithm = "zstd";
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
    extraGroups = [ "networkmanager" "wheel" "docker" "video" "render" ];
    shell = pkgs.zsh;
    packages = with pkgs; [];

    # SSH keys allowed to log in as kraeki. This is the declarative equivalent
    # of Omarchy's `omarchy-setup-security-sshd --gh-keys <user>`: NixOS writes
    # them to /etc/ssh/authorized_keys.d/kraeki, so the list is version-
    # controlled and a rebuild is the only way it changes. Public keys are
    # safe to commit. To add one from GitHub: curl https://github.com/<user>.keys
    openssh.authorizedKeys.keys = [
      # ssh.id - @kraeki
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJeUC7acuwD97EbwtmqmK3frBRZZQUia6Sr6Q91wbKlPKQ/VefWUDH5zbXXwW2s1oaOAwEwooyeDyaNKLlgfCSE="
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.kraeki = import ../../home/kraeki/home.nix;
  };

  # Wayland for Chromium-family apps (Chrome/Electron) on NixOS
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "radeonsi";  # Explicit VA-API driver for AMD
  };
  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    # Session entry point -- `hypr` is the one command to start the desktop
    # from a TTY, so the uwsm invocation is not something to memorise.
    # See programs.hyprland.withUWSM below for why uwsm is used at all.
    (writeShellScriptBin "hypr" ''
      set -euo pipefail

      # --help first, so it still answers from inside a running session.
      case "''${1:-}" in
        -h|--help)
          echo "usage: hypr [-b|--bare]"
          echo "  (no args)   start Hyprland under uwsm (systemd-managed session)"
          echo "  -b, --bare  start Hyprland directly, bypassing uwsm"
          exit 0
          ;;
      esac

      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        echo "hypr: a Wayland session is already running in this shell." >&2
        exit 1
      fi

      case "''${1:-}" in
        "") ;;
        -b|--bare)
          # Escape hatch if uwsm ever misbehaves: Hyprland's own launcher.
          # graphical-session.target then gets activated by the exec-once
          # bootstrap in hyprland.lua instead of by uwsm.
          exec ${config.programs.hyprland.package}/bin/start-hyprland
          ;;
        *)
          echo "hypr: unknown option: ''$1 (try --help)" >&2
          exit 2
          ;;
      esac

      exec ${config.programs.uwsm.package}/bin/uwsm start -e -D Hyprland hyprland.desktop
    '')

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
    docker
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

    # Desktop environment
    hyprland
    dunst
    wpaperd
    hyprlock
    kitty
    waybar
    rofi
    nautilus
    sushi             # Nautilus quick-preview (spacebar)
    papers            # GNOME document viewer (PDF, etc.)
    networkmanagerapplet
    hyprpicker

    # Hardware & Power
    brightnessctl
    pulseaudio
    bluez
    thunderbolt
    powertop
    framework-tool    # Battery charge thresholds, fan control (fw-ectool)

    # GPU diagnostics
    libva-utils       # vainfo - verify VA-API hardware decode
    vulkan-tools      # vulkaninfo - verify Vulkan
    mesa-demos        # glxinfo/eglinfo

    # Shell
    zsh
    zsh-powerlevel10k
    oh-my-zsh
    fastfetch

    # Clipboard & Screenshot
    wl-clipboard
    cliphist
    swappy
    grim
    slurp
    wf-recorder
    ffmpeg
    # OCR + QR for the Omarchy capture ports (Super+Ctrl+Print / Super+Shift+Print).
    # tesseract defaults to every language pack; pin the two actually used.
    (tesseract.override { enableLanguages = [ "eng" "deu" ]; })
    zbar

    # Utilities
    poppler-utils # for pdfunite
    vicinae      # launcher

    # Speech-to-text
    whisper-cpp  # offline transcription
    wtype        # Wayland keystroke injection

    # Neovim & dependencies
    neovim
    fzf
    clang
    ripgrep
    tree-sitter
  ];

  # programs.nano.enable = false;
  services.hardware.bolt.enable = true;

  # timesync 
  services.timesyncd.enable = true;

  services.teamviewer.enable = true;

  ## Power Management
  # Use power-profiles-daemon as recommended by AMD and Framework for Ryzen 7040
  services.power-profiles-daemon.enable = true;

  # powertop --auto-tune conflicts with power-profiles-daemon; keep powertop
  # installed for interactive diagnostics but don't let it auto-tune at boot
  powerManagement.powertop.enable = false;

  # TLP conflicts with power-profiles-daemon and is not recommended for AMD Ryzen 7040
  services.tlp.enable = false;

  # Battery charge ceiling. This laptop lives on AC, and holding a Li-ion cell
  # at 100% SoC is what actually ages it (calendar aging); cycle count is a
  # non-issue here. Capping the charge is the single highest-impact knob.
  #
  # power-profiles-daemon has no charge-threshold support and TLP is off, so
  # nothing was setting this -- the EC default is 100. The knob comes from the
  # mainline `cros_charge_control` driver (Framework EC), exposed as
  # /sys/class/power_supply/BAT1/charge_control_end_threshold. Only an *end*
  # threshold exists; the EC applies its own recharge hysteresis a few percent
  # below it. `framework-tool --charge-limit` writes the same EC register.
  #
  # Lower this to 60 if the machine essentially never leaves the dock -- that
  # roughly halves the aging rate again, at the cost of unplugged runtime.
  systemd.services.battery-charge-threshold =
    let
      limit = 80;
      # BAT1 on this board, but glob so an EC/firmware rename can't silently
      # turn this into a no-op that leaves the battery charging to 100%.
      script = pkgs.writeShellScript "battery-charge-threshold" ''
        set -eu
        found=0
        for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
          [ -w "$f" ] || continue
          echo ${toString limit} > "$f"
          found=1
        done
        [ "$found" = 1 ] || { echo "no writable charge_control_end_threshold found" >&2; exit 1; }
      '';
    in {
      description = "Cap battery charge at ${toString limit}%";
      # Re-assert after sleep: the EC keeps the limit across suspend, but not
      # across a full EC reset (shutdown / battery disconnect), and re-writing
      # it is idempotent.
      wantedBy = [ "multi-user.target" "suspend.target" "hibernate.target" ];
      after = [ "suspend.target" "hibernate.target" ];
      # No RemainAfterExit: a oneshot left "active" after boot would be skipped
      # when suspend.target pulls it in again on resume.
      serviceConfig = {
        Type = "oneshot";
        ExecStart = script;
      };
    };

  # Clamshell docking: when docked (external monitors present) closing the lid
  # must NOT suspend — Hyprland's lid-switch binds disable the internal panel
  # instead (see hyprland.lua "switch:on/off:Lid Switch"). systemd already
  # defaults HandleLidSwitchDocked=ignore; set it explicitly so it's documented
  # and stable. Undocked lid-close still suspends (HandleLidSwitch untouched).
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

  # Disable NetworkManager-wait-online (unnecessary for desktop, saves ~5s boot)
  systemd.services.NetworkManager-wait-online.enable = false;


  ## 1password needs keyring 
  services.gnome.gnome-keyring.enable = true;

  ## Steam 
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;  # Optional: only if you plan to use Remote Play
    dedicatedServer.openFirewall = false;  # Optional
  };
  
  # GPU: AMD Radeon 860M (Krackan Point, RDNA 3.5, gfx1150) - Mesa RADV for Vulkan, radeonsi for GL + VA-API
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Required for 32-bit games
    extraPackages = with pkgs; [
      vulkan-loader     # Vulkan ICD loader
      libglvnd          # libEGL.so.1 / libGL.so.1 dispatcher (Chrome/ANGLE dlopens these)
    ];
  };
  hardware.steam-hardware.enable = true;  # Enables udev rules for game controllers
  ## - Steam

  # Ollama - local LLM runner, ROCm-accelerated on the 860M (Krackan Point, gfx1150).
  # ROCm ships no official gfx1150 kernels, so we point HSA at the RDNA 3.5 target
  # gfx1151 (11.5.1) which the runtime accepts for this GPU family.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;  # ROCm build (acceleration option was removed)
    rocmOverrideGfx = "11.5.1";  # sets HSA_OVERRIDE_GFX_VERSION for the daemon
  };

  programs.hyprland.enable = true;

  # Launch Hyprland under uwsm so systemd actually owns the session lifecycle.
  #
  # Hyprland's own launcher (start-hyprland) never activates
  # graphical-session.target. That went unnoticed until xdg-desktop-portal 1.22
  # added "Requisite=graphical-session.target" to its unit -- after which D-Bus
  # activation of the portal failed instantly and Chrome/Meet screen sharing
  # broke (see the AUTOSTART block in hyprland.lua). uwsm binds the compositor
  # into graphical-session-pre/graphical-session/xdg-desktop-autostart targets,
  # which is the upstream-recommended fix rather than nudging the target awake
  # from an exec-once.
  #
  # Start it from the TTY with `hypr` (defined in environment.systemPackages
  # above), which runs `uwsm start -e -D Hyprland hyprland.desktop` -- exactly
  # what the shipped hyprland-uwsm.desktop entry runs.
  # `hypr --bare` (and plain `start-hyprland`) still work as a fallback: the
  # exec-once bootstrap in hyprland.lua stays, and is a harmless no-op once
  # uwsm has already activated the target.
  #
  # Side effect: programs.uwsm.enable flips services.dbus.implementation to
  # "broker" (dbus-broker), which uwsm recommends for compatibility.
  programs.hyprland.withUWSM = true;

  programs.zsh.enable = true;

  # Nautilus right-click "Open in Terminal" (kitty). The module also wires up
  # the required dconf setting so the entry launches kitty (not gnome-terminal).
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "kitty";
  };

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

  # Screen recording backend for capture-screenrecording.sh. The module (not a
  # bare systemPackages entry) is what installs the setcap wrapper that the kms
  # capture backend needs to grab the framebuffer.
  programs.gpu-screen-recorder.enable = true;

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
  services.upower = {
    enable = true;
    percentageLow = 15;
    percentageCritical = 8;
    percentageAction = 5;
    criticalPowerAction = "Suspend";
    allowRiskyCriticalPowerAction = true;
  };
  systemd.services.upower.restartTriggers = [ config.environment.etc."UPower/UPower.conf".source ];

  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;  # Start on first docker command, saves ~1.8s boot
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

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

  # Auto garbage-collect old generations weekly (currently 1093 generations / 196GB store)
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

}
