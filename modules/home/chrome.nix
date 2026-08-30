# Google Chrome tuned for Wayland/Hyprland on NixOS: GPU sandbox RUNPATH
# patch, gnome-keyring password store, Vulkan/VA-API acceleration.
{ config, lib, pkgs, ... }:

{
  options.nd.chrome.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "Google Chrome with Wayland, keyring, and GPU acceleration fixes.";
  };

  config = lib.mkIf config.nd.chrome.enable {
    programs.google-chrome = {
      enable = true;
      # Patch RUNPATH so the sandboxed GPU process can find libEGL.so.1 / libGL.so.1
      # via /run/opengl-driver/lib. Chrome's sandbox strips LD_LIBRARY_PATH from the
      # wrapper, so RUNPATH is the only way these libs reach the GPU process.
      package = pkgs.google-chrome.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          ${pkgs.patchelf}/bin/patchelf \
            --add-rpath /run/opengl-driver/lib \
            $out/share/google/chrome/chrome
        '';
      });
      commandLineArgs = [
        "--ozone-platform=wayland"
        # Store cookie/password encryption key via libsecret (gnome-keyring) directly.
        # Without this, Wayland Chrome tries the org.freedesktop.portal.Secret portal,
        # which isn't served in this Hyprland session (portals.conf routes only
        # hyprland;gtk, neither of which provides Secret). Init then fails, no stable
        # key is stored, Google session cookies can't persist across restarts, and
        # Workspace accounts (e.g. ajv.ch) endlessly prompt "verify it's you".
        "--password-store=gnome-libsecret"
        "--use-gl=angle"
        "--use-angle=vulkan"
        "--enable-gpu-rasterization"
        "--disable-zero-copy"
        "--ignore-gpu-blocklist"
        "--enable-features=Vulkan,VulkanFromANGLE,DefaultANGLEVulkan,AcceleratedVideoDecodeLinuxGL,VaapiIgnoreDriverChecks,IntensiveWakeUpThrottling:grace_period_seconds/10,InfiniteTabsFreezing,MemoryPurgeOnFreeze"
      ];
    };
  };
}
