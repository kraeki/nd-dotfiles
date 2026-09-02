# Locale & keyboard: English UI with regional formats, configurable per host.
{ config, lib, ... }:

let
  cfg = config.nd.locale;
in
{
  options.nd.locale = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.nd.enable;
      defaultText = lib.literalExpression "config.nd.enable";
      description = "Timezone, locale, and keyboard layout defaults.";
    };
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Berlin";
      description = "System timezone.";
    };
    regionalFormat = lib.mkOption {
      type = lib.types.str;
      default = "de_DE.UTF-8";
      description = "Locale used for dates, numbers, paper size, etc. (UI stays en_US).";
    };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = cfg.timeZone;

    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = lib.genAttrs [
      "LC_ADDRESS"
      "LC_IDENTIFICATION"
      "LC_MEASUREMENT"
      "LC_MONETARY"
      "LC_NAME"
      "LC_NUMERIC"
      "LC_PAPER"
      "LC_TELEPHONE"
      "LC_TIME"
    ] (_: cfg.regionalFormat);

    # Configure keymap in X11
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };
}
