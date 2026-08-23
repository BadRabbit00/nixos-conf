{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "BadRabbit";
        email = "Alexeyb06@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };
    };
    signing.format = null;
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
      obsidian = "cd ~/vault && git pull && obsidian .";
      davinci = "davinci-resolve";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "docker" ];
    };

    initContent = ''
      fastfetch
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[➜](bold #d33637)";
        error_symbol = "[➜](bold #611a1c)";
      };
      directory = {
        style = "bold #ac7e7c";
      };
      git_branch = {
        style = "bold #d33637";
        symbol = " ";
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
    nodejs   # Required for gemini-cli
  ];
}