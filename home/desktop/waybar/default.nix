{ config, pkgs, lib, ... }:

let
  # Твоя новая инфернальная палитра
  colors = {
    accent     = "#d33637"; # Ярко-красный
    main-bg    = "#0c0c0c"; # Бездна
    main-fg    = "#ac7e7c"; # Текст
    hover-bg   = "#611a1c"; # Кровавый ховер
    outline    = "#351212"; # Темный бордо
    
    # Слои "брони" (переходы)
    module1    = "#242424";
    module2    = "#403736";
    module3    = "#744c4c";
    module4    = "#7b615d";
    module5    = "#24241c";
    
    warning    = "#ac7e7c";
    critical   = "#d33637";
  };

  # Пробрасываем скрипты из ref папки
  scriptsDir = "${config.home.homeDirectory}/.config/waybar/scripts";
in
{
  home.packages = with pkgs; [
    brightnessctl
    fzf
    libnotify
    networkmanager
    bluez
  ];

  # Копируем скрипты в .config/waybar/scripts
  home.file.".config/waybar/scripts" = {
    source = ./scripts;
    recursive = true;
    executable = true;
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 0;
        margin = "0";
        spacing = "0";
        mode = "dock";
        reload_style_on_change = true;

        modules-left = [
          "group/user"
          "custom/left_div#1"
          "hyprland/workspaces"
          "custom/right_div#1"
          "hyprland/window"
        ];

        modules-center = [
          "hyprland/language"
          "custom/left_div#2"
          "temperature"
          "custom/left_div#3"
          "memory"
          "custom/left_div#4"
          "cpu"
          "custom/left_inv#1"
          "custom/left_div#5"
          "custom/distro"
          "custom/right_div#2"
          "custom/right_inv#1"
          "idle_inhibitor"
          "clock#time"
          "custom/right_div#3"
          "clock#date"
          "custom/right_div#4"
          "network"
          "bluetooth"
          "custom/right_div#5"
        ];

        modules-right = [
          "mpris"
          "custom/left_div#6"
          "group/pulseaudio"
          "custom/left_div#7"
          "backlight"
          "custom/left_div#8"
          "battery"
          "custom/left_inv#2"
          "custom/power_menu"
        ];

        # --- Модули Hyprland ---
        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "";
            default = "";
          };
          on-scroll-up = "hyprctl dispatch workspace +1";
          on-scroll-down = "hyprctl dispatch workspace -1";
        };

        "hyprland/window" = {
          format = "{}";
          rewrite = {
            "" = "Desktop";
            "kitty" = "Terminal";
            "zsh" = "Terminal";
          };
        };

        "hyprland/language" = {
          format-en = " en";
        };

        # --- Системные модули ---
        "clock#time" = {
          format = "{:%H:%M}";
          tooltip-format = "<b>Standard Time</b>: <span text_transform='lowercase'>{:%I:%M %p}</span>";
        };

        "clock#date" = {
          format = "󰸗 {:%d-%m}";
          tooltip-format = "{calendar}";
          calendar = {
            mode = "month";
            format = {
              months = "<span alpha='100%'><b>{}</b></span>";
              today = "<span alpha='100%'><b><u>{}</u></b></span>";
            };
          };
        };

        "cpu" = {
          interval = 10;
          format = "󰍛 {usage}%";
          states = { warning = 75; critical = 90; };
        };

        "memory" = {
          interval = 10;
          format = "󰘚 {percentage}%";
          states = { warning = 75; critical = 90; };
        };

        "temperature" = {
          critical-threshold = 90;
          format = "{icon} {temperatureC}°C";
          format-icons = [ "󱃃" "󰔏" "󱃂" ];
        };

        "battery" = {
          states = { warning = 20; critical = 10; };
          format = "{icon} {capacity}%";
          format-charging = "󰉁 {capacity}%";
          format-icons = [ "󰂎" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        };

        "network" = {
          format = "󰤨";
          format-ethernet = "󰈀";
          format-disconnected = "󰤯";
          on-click = "kitty -e ${scriptsDir}/network.sh";
        };

        "bluetooth" = {
          format = "󰂯";
          format-connected = "󰂱";
          on-click = "kitty -e ${scriptsDir}/bluetooth.sh";
        };

        "backlight" = {
          format = "{icon} {percent}%";
          format-icons = [ "" "" "" "" "" "" "" "" "" ];
          on-scroll-up = "${scriptsDir}/backlight.sh up";
          on-scroll-down = "${scriptsDir}/backlight.sh down";
        };

        "pulseaudio#output" = {
          format = "{icon} {volume}%";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
            default-muted = "󰝟";
          };
          on-click = "${scriptsDir}/volume.sh output mute";
          on-scroll-up = "${scriptsDir}/volume.sh output raise";
          on-scroll-down = "${scriptsDir}/volume.sh output lower";
        };

        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = { activated = "󰈈"; deactivated = "󰈉"; };
        };

        # --- Группы ---
        "group/user" = {
          orientation = "horizontal";
          modules = [ "custom/trigger" ];
        };

        "group/pulseaudio" = {
          orientation = "horizontal";
          modules = [ "pulseaudio#output" ];
        };

        # --- Кастомные модули (Разделители и прочее) ---
        "custom/distro" = { format = "󰣇"; tooltip = false; };
        "custom/power_menu" = {
          format = "󰤄";
          on-click = "kitty -e ${scriptsDir}/power-menu.sh";
        };
        "custom/trigger" = { format = "󰍜"; tooltip = false; };

        # Разделители (используем символы из mechabar)
        "custom/left_div#1" = { format = ""; tooltip = false; };
        "custom/left_div#2" = { format = ""; tooltip = false; };
        "custom/left_div#3" = { format = ""; tooltip = false; };
        "custom/left_div#4" = { format = ""; tooltip = false; };
        "custom/left_div#5" = { format = ""; tooltip = false; };
        "custom/left_div#6" = { format = ""; tooltip = false; };
        "custom/left_div#7" = { format = ""; tooltip = false; };
        "custom/left_div#8" = { format = ""; tooltip = false; };
        "custom/left_inv#1" = { format = ""; tooltip = false; };
        "custom/left_inv#2" = { format = ""; tooltip = false; };
        "custom/right_div#1" = { format = ""; tooltip = false; };
        "custom/right_div#2" = { format = ""; tooltip = false; };
        "custom/right_div#3" = { format = ""; tooltip = false; };
        "custom/right_div#4" = { format = ""; tooltip = false; };
        "custom/right_div#5" = { format = ""; tooltip = false; };
        "custom/right_inv#1" = { format = ""; tooltip = false; };
      };
    };

    style = ''
      * {
        all: initial;
        color: ${colors.main-fg};
        font-family: "SpaceMono Nerd Font";
        font-weight: bold;
        font-size: 14px;
      }

      #waybar {
        background-color: ${colors.outline};
      }

      #waybar > box {
        margin: 4px;
        background-color: ${colors.main-bg};
      }

      .module {
        margin-bottom: -1px;
      }

      button {
        border-radius: 16px;
        min-width: 16px;
        padding: 0 10px;
      }

      button:hover {
        background-color: ${colors.hover-bg};
        color: ${colors.accent};
      }

      /* --- Динамические цвета модулей --- */
      
      #workspaces { background-color: ${colors.module1}; }
      #workspaces button.active label { color: ${colors.accent}; }
      
      #temperature { background-color: ${colors.module2}; }
      #memory { background-color: ${colors.module3}; }
      #cpu { background-color: ${colors.module1}; }
      
      #clock.time { background-color: ${colors.module2}; }
      #clock.date { background-color: ${colors.module3}; }
      
      #network, #bluetooth { background-color: ${colors.module4}; }
      
      #pulseaudio, #backlight, #battery { background-color: ${colors.module1}; }
      
      #custom-distro { 
        background-color: ${colors.accent}; 
        color: ${colors.main-bg};
        padding: 0 10px 0 5px;
      }

      #custom-power_menu {
        color: ${colors.accent};
        padding: 0 15px;
      }

      /* --- Разделители --- */
      #custom-left_div, #custom-right_div, #custom-left_inv, #custom-right_inv {
        font-size: 20px;
      }

      #custom-left_div.1 { color: ${colors.module1}; }
      #custom-right_div.1 { color: ${colors.module1}; }
      
      #custom-left_div.2 { color: ${colors.module2}; }
      #custom-left_div.3 { background-color: ${colors.module2}; color: ${colors.module3}; }
      #custom-left_div.4 { background-color: ${colors.module3}; color: ${colors.module1}; }
      
      #custom-left_div.5 { color: ${colors.accent}; }
      #custom-right_div.2 { color: ${colors.accent}; }
      
      #custom-right_div.3 { background-color: ${colors.module3}; color: ${colors.module2}; }
      #custom-right_div.4 { background-color: ${colors.module4}; color: ${colors.module3}; }
      #custom-right_div.5 { color: ${colors.module4}; }

      #custom-left_div.6 { color: ${colors.module1}; }
      #custom-left_div.7 { background-color: ${colors.module1}; color: ${colors.module1}; }
      #custom-left_div.8 { background-color: ${colors.module1}; color: ${colors.module1}; }

      #custom-left_inv.1 { color: ${colors.module1}; }
      #custom-left_inv.2 { color: ${colors.module1}; }
      #custom-right_inv.1 { color: ${colors.module2}; }
      
      #idle_inhibitor { background-color: ${colors.module2}; }

      /* Состояния */
      #battery.warning { color: ${colors.warning}; }
      #battery.critical { color: ${colors.critical}; }
      #battery.charging { color: #a6e3a1; }
    '';
  };
}
