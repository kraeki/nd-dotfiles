{ config, pkgs, ... }:

{
  home.username = "kraeki";
  home.homeDirectory = "/home/kraeki";
  home.stateVersion = "23.11";

  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;

    shellAliases = {
      vi = "nvim";
      hc = "vi ~/.config/hypr";
      nc = "cd ~/work/nd-dotfiles/nixos-config; vi ./hosts/naptop/configuration.nix";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "per-directory-history" ]; 
      theme = ""; 
    };

    plugins = [
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
      }
    ];

    initContent = ''
      # Powerlevel10k initialisieren
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
    '';
  };

  home.packages = with pkgs; [ 
  ];
}

