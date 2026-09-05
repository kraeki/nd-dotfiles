# Binary cache for this repo's custom builds (waybar override, Handy,
# wayscriber, ...), filled by CI (.github/workflows/build.yml).
#
# Setup (once): create a cache at https://app.cachix.org, then set
#   nd.cache.url = "https://<name>.cachix.org";
#   nd.cache.publicKey = "<name>.cachix.org-1:...";  # shown on the cache page
# and give the GitHub repo the CACHIX_CACHE variable + CACHIX_AUTH_TOKEN
# secret so CI can push. Until both options are set, this module is inert.
{ config, lib, ... }:

let
  cfg = config.nd.cache;
in
{
  options.nd.cache = {
    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://nd-kraeki.cachix.org";
      description = "Substituter URL of the project binary cache.";
    };
    publicKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "nd-kraeki.cachix.org-1:AAAA...=";
      description = "Public signing key of the project binary cache.";
    };
  };

  config = lib.mkIf (cfg.url != null && cfg.publicKey != null) {
    # extra-* so cache.nixos.org stays first-class.
    nix.settings.extra-substituters = [ cfg.url ];
    nix.settings.extra-trusted-public-keys = [ cfg.publicKey ];
  };
}
