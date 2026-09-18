# Printing & scanning: CUPS driving printers over IPP with no vendor driver,
# Avahi for DNS-SD so they are found wherever the laptop is, and SANE for the
# scanner half of an all-in-one.
#
# Hosts declare their actual queues (see hosts/naptop) — a specific printer at
# a specific address is a per-machine choice, not part of the profile.
{ config, lib, pkgs, ... }:

{
  options.nd.printing = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.nd.enable;
      defaultText = lib.literalExpression "config.nd.enable";
      description = "CUPS with driverless IPP printing and Avahi/DNS-SD discovery.";
    };

    scanning.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.nd.printing.enable;
      defaultText = lib.literalExpression "config.nd.printing.enable";
      description = "SANE and a GUI frontend, for the scanner side of an all-in-one.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.nd.printing.enable {
      services.printing = {
        enable = true;

        # cups-filters supplies the PDF -> raster chain CUPS needs for printers
        # that are NOT driverless. Driverless ones need nothing here: `lpadmin
        # -m everywhere` asks the printer for its IPP attributes and builds the
        # PPD from the answer, so no vendor blob is involved at all. Prefer that
        # path always — the Brother/HP/Canon .debs are unfree, 32-bit, and rot.
        drivers = [ pkgs.cups-filters ];

        # cups-browsed is on by default in nixpkgs and is NOT wanted here. It
        # bridges the CUPS 1.x broadcast protocol into local queues, which no
        # modern printer speaks, and is deprecated upstream — all it does on a
        # DNS-SD network is invent duplicate queues that come and go. CUPS does
        # its own DNS-SD enumeration client-side (via Avahi, below), so nothing
        # is lost by switching it off.
        browsed.enable = false;
      };

      # DNS-SD, two jobs:
      #   1. CUPS enumerates printers on whatever LAN we are on, so the GTK
      #      print dialog lists them with no queue declared at all.
      #   2. `.local` names resolve, so a declared queue can be pinned to the
      #      printer's Bonjour hostname instead of a DHCP lease.
      # openFirewall is the UDP 5353 hole the replies come back through; without
      # it mDNS queries time out ("All attempts to contact name servers or
      # networks failed") and nothing on the LAN is ever discovered.
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      # systemd-resolved (modules/nixos/networking.nix) speaks mDNS too and
      # holds UDP 5353 by default — `resolvectl mdns` reports "yes" on every
      # link. Avahi cannot bind the port underneath it, so exactly one of the
      # two responders may be on, and it has to be Avahi: CUPS' discovery talks
      # to Avahi over D-Bus and has no systemd-resolved equivalent.
      services.resolved.settings.Resolve.MulticastDNS = "no";

      # Queue management outside the app print dialog (pause, cancel, re-add).
      environment.systemPackages = [ pkgs.system-config-printer ];

      # `hardware.printers.ensurePrinters` with `model = "everywhere"` runs
      # `lpadmin -m everywhere`, which QUERIES the printer over IPP — so the
      # generated ensure-printers unit only succeeds while the printer is
      # actually reachable, and nixpkgs orders it after nothing but
      # cups.service. Two things have to be true first:
      #
      #   1. avahi-daemon must be serving. A queue addressed by its Bonjour
      #      name resolves through nss-mdns, i.e. through Avahi — NOT through
      #      systemd-resolved, whose mDNS is deliberately off above. Without
      #      this ordering the first run after a switch dies on "lpadmin:
      #      Unable to connect to <name>.local:631: Name or service not known"
      #      while the very same name resolves fine seconds later.
      #   2. The network must be up. On a laptop that is a race the unit
      #      routinely loses at boot — NetworkManager-wait-online is off here,
      #      so network-online.target is nearly free and settles nothing.
      #
      # Ordering fixes (1) outright; (2) is what the bounded retry is for:
      # five tries over ~2.5 minutes, then it gives up rather than turning
      # into a background poller. Giving up is cheap — the queue lives in
      # /var/lib/cups once created, so a failure away from home costs nothing
      # but a red unit.
      systemd.services.ensure-printers =
        lib.mkIf (config.hardware.printers.ensurePrinters != [ ]) {
          after = [ "network-online.target" "avahi-daemon.service" ];
          wants = [ "network-online.target" "avahi-daemon.service" ];
          startLimitIntervalSec = 300;
          startLimitBurst = 5;
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = 30;
          };
        };
    })

    (lib.mkIf config.nd.printing.scanning.enable {
      # Creates the "scanner" group; users have to be added to it (hosts do that).
      hardware.sane.enable = true;

      environment.systemPackages = [ pkgs.simple-scan ];
    })
  ];
}
