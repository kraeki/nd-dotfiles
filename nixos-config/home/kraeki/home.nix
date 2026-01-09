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

      # z-lua initialization
      eval "$(${pkgs.z-lua}/bin/z --init zsh enhanced once)"
    '';
  };

  home.packages = with pkgs; [
    # Productivity & Communication
    obsidian
    _1password-gui
    seahorse
    slack
    claude-code
    gemini-cli
    google-chrome

    # Creative
    audacity
    inkscape
    gimp
    davinci-resolve-studio

    # Entertainment
    steam
    protontricks
    mplayer

    # Development tools
    lazygit          # TUI for git (LazyVim integration)
    python3          # Python runtime for LSPs and tools
    glib             # Provides gio trash command
    ast-grep         # Structural search/replace
    ghostscript      # PDF rendering in neovim
    chafa            # Image preview in terminal/fzf

    # Shell utilities
    z-lua

    # Misc
    teamviewer
  ];
}

