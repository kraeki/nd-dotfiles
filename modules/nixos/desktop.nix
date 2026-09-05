# Desktop layer: Hyprland (under uwsm), the bar/launcher/notification stack,
# bluetooth, graphics, clipboard/screenshot tooling.
{ config, lib, pkgs, ... }:

{
  options.nd.desktop.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "Hyprland desktop: compositor, bar, launcher, notifications, screenshots.";
  };

  config = lib.mkIf config.nd.desktop.enable {
    # Waybar pinned past 0.15.0 for Hyprland Lua-IPC dispatch — see
    # overlays/waybar.nix (shared with the flake's `waybar` package output
    # so CI can pre-build and cache the same derivation).
    nixpkgs.overlays = [ (import ../../overlays/waybar.nix) ];

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
    # below), which runs `uwsm start -e -D Hyprland hyprland.desktop` -- exactly
    # what the shipped hyprland-uwsm.desktop entry runs.
    # `hypr --bare` (and plain `start-hyprland`) still work as a fallback: the
    # exec-once bootstrap in hyprland.lua stays, and is a harmless no-op once
    # uwsm has already activated the target.
    #
    # Side effect: programs.uwsm.enable flips services.dbus.implementation to
    # "broker" (dbus-broker), which uwsm recommends for compatibility.
    programs.hyprland.withUWSM = true;

    # Wayland for Chromium-family apps (Chrome/Electron) on NixOS
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # Enable bluetooth
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;

    # GPU: Mesa for the compositor + Vulkan loader / GL dispatch for apps
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        vulkan-loader     # Vulkan ICD loader
        libglvnd          # libEGL.so.1 / libGL.so.1 dispatcher (Chrome/ANGLE dlopens these)
      ];
    };

    ## 1password needs keyring
    services.gnome.gnome-keyring.enable = true;

    # Screen recording backend for capture-screenrecording.sh. The module (not a
    # bare systemPackages entry) is what installs the setcap wrapper that the kms
    # capture backend needs to grab the framebuffer.
    programs.gpu-screen-recorder.enable = true;

    # Nautilus right-click "Open in Terminal" (kitty). The module also wires up
    # the required dconf setting so the entry launches kitty (not gnome-terminal).
    programs.nautilus-open-any-terminal = {
      enable = true;
      terminal = "kitty";
    };

    environment.systemPackages = with pkgs; [
      # Session entry point -- `hypr` is the one command to start the desktop
      # from a TTY, so the uwsm invocation is not something to memorise.
      # See programs.hyprland.withUWSM above for why uwsm is used at all.
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

      # Display & input
      brightnessctl
      pulseaudio
      bluez

      # GPU diagnostics
      libva-utils       # vainfo - verify VA-API hardware decode
      vulkan-tools      # vulkaninfo - verify Vulkan
      mesa-demos        # glxinfo/eglinfo

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
    ];
  };
}
