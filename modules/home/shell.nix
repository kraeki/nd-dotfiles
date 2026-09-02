# Shell: zsh + oh-my-zsh + Powerlevel10k, fzf integration, z-lua jumping.
# Personal aliases stay in the user's home.nix (they merge into programs.zsh).
{ config, lib, pkgs, ... }:

{
  options.nd.shell.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "zsh with oh-my-zsh, Powerlevel10k, fzf, and z-lua.";
  };

  config = lib.mkIf config.nd.shell.enable {
    programs.zsh = {
      enable = true;

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

        # npm global packages
        export PATH="$HOME/.npm-global/bin:$PATH"
      '';
    };

    # Fuzzy finder with zsh integration (Ctrl-R history, Ctrl-T files, Alt-C cd).
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    home.packages = [ pkgs.z-lua ];
  };
}
