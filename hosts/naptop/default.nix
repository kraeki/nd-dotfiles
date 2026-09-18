# naptop — Framework Laptop 13 (Ryzen AI 300, Krackan Point). This file holds
# only what is true of THIS machine: hardware, boot, kernel quirks, its user.
# Everything identity-shaped comes from modules/nixos via `nd.enable = true`.
# (The previous Framework 16 lives on as hosts/naptop-old.)
{ config, pkgs, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
    # Declarative disk layout for wipe-reinstalls (inert on the running
    # system — see the mode notes in disko.nix).
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  # The nd profile (modules/nixos), whole thing on.
  nd.enable = true;

  networking.hostName = "naptop";

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

  # AMD CPU microcode updates for stability and security
  hardware.cpu.amd.updateMicrocode = true;

  # Explicit VA-API driver for the AMD Radeon 780M (radeonsi)
  environment.sessionVariables.LIBVA_DRIVER_NAME = "radeonsi";

  # Thunderbolt / USB4 docking
  services.hardware.bolt.enable = true;

  environment.systemPackages = with pkgs; [
    thunderbolt
    framework-tool    # Battery charge thresholds, fan control (fw-ectool)
  ];

  # Ollama - local LLM runner, ROCm-accelerated on the 860M (Krackan Point, gfx1150).
  # ROCm ships no official gfx1150 kernels, so we point HSA at the RDNA 3.5 target
  # gfx1151 (11.5.1) which the runtime accepts for this GPU family.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;  # ROCm build (acceleration option was removed)
    rocmOverrideGfx = "11.5.1";  # sets HSA_OVERRIDE_GFX_VERSION for the daemon
  };

  # The home printer: a Brother DCP-9015CDW colour laser MFP on the flat's LAN.
  # The capability (CUPS, Avahi, SANE) comes from nd.printing; only the queue
  # itself is per-machine, so it lives here.
  #
  # Driverless. The device answers Get-Printer-Attributes with
  # document-format-supported = image/urf, image/pwg-raster -- i.e. it is an
  # AirPrint/IPP-Everywhere printer -- so `model = "everywhere"` has CUPS build
  # the PPD from the printer's own answer. Brother's unfree `dcpl`/`cupswrapper`
  # .debs are not needed and should not be reached for.
  #
  # Addressed by its Bonjour name, not 192.168.13.123: the IP is a DHCP lease
  # and would silently break the queue the day the router hands out another.
  # Resolving this needs Avahi up (nd.printing) -- and note `lpadmin -m
  # everywhere` QUERIES the printer, so the ensure-printers unit fails while
  # away from home or with the printer asleep. That failure is inert: the queue
  # persists in /var/lib/cups once created.
  hardware.printers = {
    ensureDefaultPrinter = "brother";
    ensurePrinters = [{
      name = "brother";
      description = "Brother DCP-9015CDW";
      location = "Home";
      deviceUri = "ipp://BRW90CDB653E86D.local:631/ipp/print";
      model = "everywhere";
      ppdOptions = {
        PageSize = "A4";
        # The printer's own sides-default is two-sided-long-edge; keep it.
        Duplex = "DuplexNoTumble";
      };
    }];
  };

  # Scanning. The DCP is an all-in-one, but it speaks NEITHER eSCL/AirScan
  # (/eSCL/ScannerCapabilities 404s) NOR WSD (port 5357 closed) -- so
  # sane-airscan, the driverless path that would mirror IPP Everywhere, cannot
  # see it. What it does expose is Brother's own network-scan protocol on TCP
  # 54921, which only the unfree brscan4 backend speaks. DCP-9015CDW is in that
  # backend's model table (models4/ext_15.ini), so it is supported.
  #
  # Addressed by IP here, unlike the print queue above: brscan4's `nodename=`
  # lookup is Brother's own broadcast discovery, not mDNS, and does not go
  # through Avahi at all. Give the printer a DHCP reservation on the router so
  # this address is as stable as the Bonjour name is.
  hardware.sane.brscan4 = {
    enable = true;
    netDevices.brother = {
      model = "DCP-9015CDW";   # must match brscan4's table verbatim
      ip = "192.168.13.123";
    };
  };

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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kraeki = {
    isNormalUser = true;
    description = "Andreas Schmid";
    # "scanner" + "lp": SANE's device permissions (nd.printing.scanning). Both
    # are needed — hardware.sane's udev rules grant the scanner group, and the
    # brscan4 backend also wants lp.
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" "video" "render" "scanner" "lp" ];
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
    users.kraeki = import ../../users/kraeki/home.nix;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
