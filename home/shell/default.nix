{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    extraConfig = {
      user = {
        name = "BadRabbit";
        email = "change-me@example.com";
      };
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    shellAliases = {
      ll = "eza -l -g --icons";
      ls = "eza --icons";
      cat = "bat";
      grep = "rg";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "docker" ];
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
    };
  };

  # Cool CLI tools
  home.packages = with pkgs; [
    bat      # Better cat
    eza      # Better ls
    ripgrep  # Better grep
    fzf      # Fuzzy finder
    jq       # JSON processor
    btop     # Better htop
    fastfetch # System info
  ];
}
