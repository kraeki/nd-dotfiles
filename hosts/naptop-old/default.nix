# naptop-old — the previous machine, a Framework Laptop 16 (Ryzen 7040),
# preserved so it can still be rebuilt. Hostname stays "naptop" (mirrors the
# archived config on main). Hardware truth only; identity comes from
# modules/nixos via `nd.enable = true`.
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.framework-16-7040-amd
  ];

  # The nd profile (modules/nixos), whole thing on.
  nd.enable = true;

  networking.hostName = "naptop";

  # The archived config on main runs Hyprland without uwsm — mirror that
  # (the nd desktop profile turns it on by default).
  programs.hyprland.withUWSM = lib.mkForce false;

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

  # This machine signs its store paths (key exists only here).
  nix.settings.secret-key-files = [ "/etc/nix/signing-key.sec" ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kraeki = {
    isNormalUser = true;
    description = "Andreas Schmid";
    extraGroups = [ "networkmanager" "wheel" "docker" "video" "render" ];
    shell = pkgs.zsh;
    packages = with pkgs; [];
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
