# libvirt/QEMU-KVM, for guests that need their own kernel and bootloader --
# what docker.nix cannot cover. Hosts add users to the "libvirtd" group
# themselves (see hosts/naptop): like "docker", that group is root-equivalent,
# so it stays a per-machine decision rather than part of the profile.
#
# Deliberately libvirt+virt-manager rather than the alternatives: VirtualBox
# needs an out-of-tree kernel module, and this profile tracks
# linuxPackages_latest, so every kernel bump is a chance for the build to break
# on a module that has not caught up. GNOME Boxes is the same QEMU underneath
# but hides virtio disk/net, host CPU passthrough and snapshots. quickemu is a
# wrapper rather than a manager, and composes fine alongside this.
#
# Nothing is needed on the kernel side -- AMD-V is in the CPU flags and
# /dev/kvm already exists, so this is purely the userspace stack.
{ config, lib, pkgs, ... }:

{
  options.nd.libvirt.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "libvirt/QEMU-KVM full VMs, with virt-manager (nothing autostarts).";
  };

  config = lib.mkIf config.nd.libvirt.enable {
    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";      # same stance as docker - guests are started by hand
      onShutdown = "shutdown";
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;    # guests run as the qemu-libvirtd user, not root
        swtpm.enable = true;  # emulated TPM 2.0 - a Windows 11 guest refuses to install without one
        # No `ovmf` block: that submodule was removed from nixpkgs (the
        # assertion fires on eval) - every OVMF image, secure-boot variants
        # included, now ships with qemu and is found through its firmware
        # descriptors.
        # virtiofs shares (host directory -> guest) are a vhost-user device, so
        # the daemon has to be listed here for virt-manager's "Filesystem"
        # device to have a backend.
        vhostUserPackages = [ pkgs.virtiofsd ];
      };
    };
    virtualisation.spiceUSBRedirection.enable = true;  # setuid helper for USB passthrough

    programs.virt-manager.enable = true;

    # No VFIO/GPU passthrough: on the machines this profile targets the iGPU is
    # the only display adapter, so it cannot be handed to a guest. Guests get
    # virtio-gpu, which is fine for desktop Linux and Windows office work.
  };
}
