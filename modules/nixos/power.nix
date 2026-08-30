# Power management: power-profiles-daemon (not TLP — see comments), laptop-mode
# sysctls, zram, upower thresholds, clamshell-docking lid behavior.
{ config, lib, pkgs, ... }:

{
  options.nd.power.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "Laptop power management: power-profiles-daemon, sysctls, zram, upower.";
  };

  config = lib.mkIf config.nd.power.enable {
    # Use power-profiles-daemon as recommended by AMD and Framework for Ryzen 7040
    services.power-profiles-daemon.enable = true;

    # powertop --auto-tune conflicts with power-profiles-daemon; keep powertop
    # installed for interactive diagnostics but don't let it auto-tune at boot
    powerManagement.powertop.enable = false;

    # TLP conflicts with power-profiles-daemon and is not recommended for AMD Ryzen 7040
    services.tlp.enable = false;

    environment.systemPackages = [ pkgs.powertop ];

    # Kernel power management parameters (ArchWiki recommendations)
    boot.kernel.sysctl = {
      "kernel.nmi_watchdog" = 0;           # Disable NMI watchdog to reduce power consumption
      "vm.dirty_writeback_centisecs" = 6000;  # Aggregate disk I/O (60s vs default 5s)
      "vm.laptop_mode" = 5;                # Batch I/O operations for better power efficiency
      "vm.swappiness" = 10;               # Prefer RAM, use zram only as safety net
      "vm.vfs_cache_pressure" = 50;       # Keep more filesystem metadata cached (32GB RAM)
    };

    # Zram: compressed in-RAM swap as OOM safety net
    zramSwap = {
      enable = true;
      memoryPercent = 25;
      algorithm = "zstd";
    };

    # Clamshell docking: when docked (external monitors present) closing the lid
    # must NOT suspend — Hyprland's lid-switch binds disable the internal panel
    # instead (see hyprland.lua "switch:on/off:Lid Switch"). systemd already
    # defaults HandleLidSwitchDocked=ignore; set it explicitly so it's documented
    # and stable. Undocked lid-close still suspends (HandleLidSwitch untouched).
    services.logind.settings.Login.HandleLidSwitchDocked = "ignore";

    services.upower = {
      enable = true;
      percentageLow = 15;
      percentageCritical = 8;
      percentageAction = 5;
      criticalPowerAction = "Suspend";
      allowRiskyCriticalPowerAction = true;
    };
    systemd.services.upower.restartTriggers = [ config.environment.etc."UPower/UPower.conf".source ];
  };
}
