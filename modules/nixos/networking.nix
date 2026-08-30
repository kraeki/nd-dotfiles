# Networking & remote access: NetworkManager + systemd-resolved, Tailscale,
# SSH (key-only, Tailscale-reachable), TeamViewer.
{ config, lib, pkgs, ... }:

{
  options.nd.networking.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "NetworkManager with systemd-resolved, Tailscale, hardened SSH, TeamViewer.";
  };

  config = lib.mkIf config.nd.networking.enable {
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

    # Disable NetworkManager-wait-online (unnecessary for desktop, saves ~5s boot)
    systemd.services.NetworkManager-wait-online.enable = false;

    services.tailscale.enable = true;
    networking.firewall.checkReversePath = "loose";
    networking.firewall.trustedInterfaces = [ "tailscale0" ];

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

    services.teamviewer.enable = true;
  };
}
