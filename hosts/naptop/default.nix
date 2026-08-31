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
