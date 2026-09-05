# The nd home profile (home-manager side). Same contract as modules/nixos:
# import, set `nd.enable = true`, toggle individual nd.* options.
{ lib, ... }:

{
  imports = [
    ./chrome.nix
    ./shell.nix
  ];

  options.nd.enable = lib.mkEnableOption "the nd home profile (all nd.* home modules default to this)";
}
