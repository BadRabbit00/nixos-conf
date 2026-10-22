{ config, lib, pkgs, isNixOS ? true, ... }:

let
  # Секреты sops -> переменные окружения в каждой интерактивной сессии.
  # Расшифрованное лежит в tmpfs (/run/secrets или $XDG_RUNTIME_DIR/secrets),
  # в /nix/store попадают только имена. Новый секрет = строка здесь плюс
  # объявление в modules/core/secrets.nix и home/secrets.nix.
  secretEnv = {
    CONTEXT7_API_KEY = "context7_api_key";
    WIKI_TOKEN = "wiki_token";
  };
  secretsDir = if isNixOS then "/run/secrets" else config.sops.defaultSymlinkPath;

  # Хук на каждый промпт: после `switch` свежие значения подхватывает и уже
  # открытый терминал. `$(<file)` читает без fork, цена на промпт ничтожна.
  loadSecretEnv = ''
    __sops_env_load() {
      local f
      ${lib.concatStringsSep "\n      " (lib.mapAttrsToList (var: name: ''
        f=${lib.escapeShellArg "${secretsDir}/${name}"}
        [ -r "$f" ] && export ${var}="$(<"$f")"'') secretEnv)}
      return 0
    }
    __sops_env_load
  '';
in
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
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "docker" ];
    };

    initContent = ''
      ${loadSecretEnv}
      precmd_functions+=(__sops_env_load)
      fastfetch
    '';
  };

  # На Arch bash включён ради niri-session; на NixOS его не трогаем.
  programs.bash.initExtra = lib.mkIf config.programs.bash.enable ''
    ${loadSecretEnv}
    PROMPT_COMMAND="__sops_env_load''${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
  '';

  # direnv: шелл сам поднимает devShell проекта по .envrc (`use flake`).
  # nix-direnv кэширует окружение в .direnv/ и держит его в gcroots, чтобы
  # `cd` не запускал eval флейка каждый раз и GC не выметал toolchain.
  # Хуки в zsh/bash HM вешает сам (enable*Integration по умолчанию true).
  # Доверие остаётся ручным: новый .envrc требует `direnv allow`.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global = {
      hide_env_diff = true; # не спамить списком переменных при каждом cd
      warn_timeout = "60s"; # холодный eval тяжёлого флейка дольше дефолтных 5s
    };
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