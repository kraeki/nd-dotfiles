# Your home config: the nd home profile plus whatever is yours.
# (nd's home modules are injected via home-manager.sharedModules in flake.nix.)
{ config, pkgs, ... }:

{
  # The nd home profile (shell with zsh/p10k/fzf/z-lua, tuned Chrome).
  nd.enable = true;
  # nd.chrome.enable = false;

  home.username = "me";
  home.homeDirectory = "/home/me";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  # Personal aliases merge into the nd shell profile.
  programs.zsh.shellAliases = {
    vi = "nvim";
  };

  home.packages = with pkgs; [
    firefox
  ];
}
