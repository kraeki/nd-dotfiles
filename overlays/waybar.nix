# Waybar: pin to the upstream fix for Hyprland 0.54+ Lua IPC dispatch.
# 0.15.0 sends the legacy text command "dispatch workspace N" over the
# socket, which Hyprland now parses as invalid Lua, silently breaking
# workspace clicks and scroll in the bar. Commit e17c0d9f adds protocol
# auto-detection (hl.dsp.* on Lua-IPC Hyprland, legacy text otherwise).
# Remove this override once nixpkgs ships waybar > 0.15.0 with the fix.
#
# Used from modules/nixos/desktop.nix (the system bar) and flake.nix
# (the `waybar` package output, so CI can pre-build and cache it).
final: prev: {
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
}
