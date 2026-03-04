{ pkgs, config, ... }:

{
  home.packages = with pkgs; [
    # Browsers
    firefox
    google-chrome

    # Editors
    vscode
    nano
    antigravity

    # File Manager
    thunar
    thunar-archive-plugin
    thunar-volman
    
    # System Tray Tools
    networkmanagerapplet # Network icon in tray
    pasystray            # Audio icon in tray

    # Theming Tools
    hyprpicker
    wl-clipboard
    fastfetch

    # Messengers
    telegram-desktop
    discord

    # Media/Recording
    obs-studio

    # Misc
    spotify
    mangohud
  ];

  # --- Gemini CLI Configuration ---
  # Пробрасываем файлы конфигурации gemini-cli
  xdg.configFile."gemini/settings.json".source = ./gemini/settings.json;
  xdg.configFile."gemini/trustedFolders.json".source = ./gemini/trustedFolders.json;
  xdg.configFile."gemini/state.json".source = ./gemini/state.json;
  xdg.configFile."gemini/GEMINI.md".source = ./gemini/GEMINI.md;

  # ВАЖНО: Секреты (CONTEXT7_API_KEY, GITHUB_TOKEN) должны быть в твоем
  # системном окружении или управляться через sops-nix / git-crypt.
  # Я убрала их отсюда, чтобы не слить в репозиторий.
  
  # --- Btop Configuration ---
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "infernal-blood";
      theme_background = false; # Прозрачный фон, чтобы видеть блюр Hyprland
      truecolor = true;
      force_tty = false;
      presets = "cpu:0:default,mem:0:default,net:0:default,proc:0:default";
      graph_symbol = "braille";
      proc_sorting = "cpu lazy";
      proc_reversed = false;
      proc_tree = true;
      check_temp = true;
      draw_clock = "%H:%M:%S";
      background_update = true;
      custom_cpu_name = "";
      disks_filter = "";
      mem_graphs = true;
      mem_below_net = false;
      show_disks = true;
    };
  };

  # Кастомная тема btop
  home.file.".config/btop/themes/infernal-blood.theme".text = ''
    # Infernal Blood Theme
    theme[main_bg]="#0c0c0c"
    theme[main_fg]="#ac7e7c"
    theme[title]="#d33637"
    theme[hi_fg]="#d33637"
    theme[selected_bg]="#611a1c"
    theme[selected_fg]="#d33637"
    theme[inactive_fg]="#351212"
    theme[graph_text]="#ac7e7c"
    theme[meter_bg]="#351212"
    theme[proc_misc]="#d33637"
    theme[cpu_box]="#d33637"
    theme[mem_box]="#611a1c"
    theme[net_box]="#351212"
    theme[proc_box]="#403736"
    theme[div_line]="#351212"
    theme[temp_start]="#ac7e7c"
    theme[temp_mid]="#611a1c"
    theme[temp_end]="#d33637"
    theme[cpu_start]="#ac7e7c"
    theme[cpu_mid]="#611a1c"
    theme[cpu_end]="#d33637"
    theme[free_start]="#ac7e7c"
    theme[free_mid]="#611a1c"
    theme[free_end]="#d33637"
    theme[cached_start]="#ac7e7c"
    theme[cached_mid]="#611a1c"
    theme[cached_end]="#d33637"
    theme[available_start]="#ac7e7c"
    theme[available_mid]="#611a1c"
    theme[available_end]="#d33637"
    theme[used_start]="#ac7e7c"
    theme[used_mid]="#611a1c"
    theme[used_end]="#d33637"
    theme[download_start]="#ac7e7c"
    theme[download_mid]="#611a1c"
    theme[download_end]="#d33637"
    theme[upload_start]="#ac7e7c"
    theme[upload_mid]="#611a1c"
    theme[upload_end]="#d33637"
  '';

  # --- Fastfetch Configuration ---
  xdg.configFile."fastfetch/config.jsonc".text = ''
    {
      "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
      "logo": {
        "type": "kitty",
        "source": "~/.config/fastfetch/logo.png",
        "height": 18,
        "padding": {
          "top": 1,
          "left": 2,
          "right": 2
        }
      },
      "display": {
        "separator": " ➜  ",
        "color": {
          "keys": "red",
          "title": "red"
        }
      },
      "modules": [
        "title",
        "separator",
        {
          "type": "os",
          "key": "󱄅 OS",
          "keyColor": "red"
        },
        {
          "type": "host",
          "key": "󰌢 Host",
          "keyColor": "red"
        },
        {
          "type": "kernel",
          "key": "󰌢 Kernel",
          "keyColor": "red"
        },
        {
          "type": "uptime",
          "key": "󰅐 Uptime",
          "keyColor": "red"
        },
        {
          "type": "packages",
          "key": "󰏖 Packages",
          "keyColor": "red"
        },
        "break",
        {
          "type": "display",
          "key": "󰍹 Display",
          "keyColor": "red"
        },
        {
          "type": "cpu",
          "key": "󰻠 CPU",
          "keyColor": "red"
        },
        {
          "type": "gpu",
          "key": "󰢮 GPU",
          "keyColor": "red"
        },
        {
          "type": "memory",
          "key": "󰘚 Memory",
          "keyColor": "red"
        },
        {
          "type": "disk",
          "key": "󰋊 Disk",
          "keyColor": "red"
        },
        {
          "type": "battery",
          "key": "󰁹 Battery",
          "keyColor": "red"
        },
        "break",
        {
          "type": "wm",
          "key": "󱂬 WM",
          "keyColor": "red"
        },
        {
          "type": "shell",
          "key": "󰆍 Shell",
          "keyColor": "red"
        },
        {
          "type": "terminal",
          "key": "󰆍 Terminal",
          "keyColor": "red"
        },
        "break",
        {
          "type": "localip",
          "key": "󰩟 IP",
          "keyColor": "red"
        }
      ]
    }
  '';

  # Пробрасываем logo.png в конфиг fastfetch
  xdg.configFile."fastfetch/logo.png".source = ./logo.png;

  # Configure Nano
  home.file.".nanorc".text = ''
    set linenumbers
    set tabsize 2
    set tabstospaces
  '';
}
