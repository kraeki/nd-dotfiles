# Shell: zsh + oh-my-zsh + Powerlevel10k, fzf integration, z-lua jumping,
# direnv per-directory environments.
# Personal aliases stay in the user's home.nix (they merge into programs.zsh).
{ config, lib, pkgs, ... }:

{
  options.nd.shell.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "zsh with oh-my-zsh, Powerlevel10k, fzf, z-lua, and direnv.";
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

    # Per-directory environment from .envrc files; auto-hooks into zsh above.
    # Two uses here:
    #   1. Identity separation — an .envrc can set CLAUDE_CONFIG_DIR so a whole
    #      directory tree uses its own Claude Code profile (separate credentials,
    #      settings, history). Claude Code has no path-conditional config of its
    #      own; relocating the config dir is the only per-directory lever.
    #   2. Toolchains — `use nix` enters a repo's shell.nix on cd, and nix-direnv
    #      caches the evaluation so re-entry is instant.
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;

      # `use nix` re-exports the whole nix-shell environment, so the default
      # env-diff line lists ~60 build vars (AR, CC, buildPhase, stdenv, ...) on
      # every cd. Hide the diff and keep the short "loading/using nix" lines,
      # which are the useful part. (direnv.toml; needs direnv >= 2.36.)
      config.global.hide_env_diff = true;
    };

    # Fuzzy finder with zsh integration (Ctrl-R history, Ctrl-T files, Alt-C cd).
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    home.packages = [ pkgs.z-lua ];
  };
}
