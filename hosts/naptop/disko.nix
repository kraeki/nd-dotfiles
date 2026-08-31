# naptop (Framework 13, Ryzen AI 300) disk layout for a wipe-and-reinstall
# (disko / nixos-anywhere). Mirrors what the machine runs today: GPT, ESP at
# /boot, LUKS2 ext4 root, plus a LUKS-encrypted swap partition (the FW13
# install has one — the live scan can't reveal its size, so adjust `size`
# below to the real value before the first reinstall). LUKS passphrase at
# install time comes from the file named in `passwordFile` — see
# "Bare-metal reinstall" in the README.
#
# IMPORTANT — two modes:
#   * Today (enableConfig = false below): this layout is documentation +
#     partitioning plan only. The RUNNING system keeps mounting via the
#     UUIDs in hardware-configuration.nix. Importing this file changes
#     nothing about the current boot.
#   * Reinstall day: a wipe creates new UUIDs, so BEFORE running
#     nixos-anywhere: (1) delete the enableConfig line below so disko
#     generates fileSystems/boot config from this layout (stable
#     by-partlabel paths), (2) regenerate the hardware file without
#     mounts: `sudo nixos-generate-config --no-filesystems
#     --show-hardware-config > hardware-configuration.nix`, (3) commit.
#     From then on this file owns the mounts, reinstalls are repeatable.
{ ... }:

{
  disko.enableConfig = false;

  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        esp = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        swap = {
          size = "32G";  # ← set to the machine's real swap size before reinstalling
          content = {
            type = "luks";
            name = "cryptswap";
            passwordFile = "/tmp/disk.key";
            settings.allowDiscards = true;
            content = { type = "swap"; };
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # Consumed at format time by `nixos-anywhere
            # --disk-encryption-keys /tmp/disk.key <local-file>`.
            passwordFile = "/tmp/disk.key";
            settings.allowDiscards = true;  # TRIM through LUKS
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
