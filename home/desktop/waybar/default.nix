{ config, pkgs, lib, ... }:

let
  colors = {
    accent     = "#d33637"; # Кроваво-красный
    main-bg    = "#0c0c0c"; # Бездна
    main-fg    = "#ac7e7c"; # Текст
    hover-bg   = "#611a1c"; # Кровавый ховер
    outline    = "#351212"; # Темный бордо
    module-bg  = "rgba(12, 12, 12, 0.85)"; # Полупрозрачный фон пузырьков
  };

  scriptsDir = "${config.home.homeDirectory}/.config/waybar/scripts";
in
{
  home.packages = with pkgs; [
    brightnessctl
    fzf
    libnotify
    networkmanager
    bluez
    pulseaudio
  ];

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
        height = 30;
        margin-top = 5;
        margin-left = 10;
        margin-right = 10;
        spacing = 8;

        modules-left = [
          "niri/workspaces"
        ];

        modules-center = [
          "niri/window"
        ];

        modules-right = [
          "group/hardware"
        ];

        "niri/workspaces" = {
          format = "{index}";
          on-scroll-up = "niri msg action focus-workspace-up";
          on-scroll-down = "niri msg action focus-workspace-down";
        };

        "niri/window" = {
          format = "{}";
          separate-outputs = true;
          max-length = 50;
        };

        "group/hardware" = {
          orientation = "horizontal";
          modules = [
            "network"
            "bluetooth"
            "pulseaudio"
            "backlight"
            "battery"
            "clock#time"
            "clock#date"
          ];
        };

        "clock#time" = {
          format = "{:%H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "clock#date" = {
          format = "{:%d-%m}";
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
          device = "intel_backlight";
          format = "{icon} {percent}%";
          format-icons = [ "" "" "" "" "" "" "" "" "" ];
          on-scroll-up = "${scriptsDir}/backlight.sh up";
          on-scroll-down = "${scriptsDir}/backlight.sh down";
        };

        "pulseaudio" = {
          format = "{icon} {volume}%";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
            default-muted = "󰝟";
          };
          on-click = "${scriptsDir}/volume.sh output mute";
          on-scroll-up = "${scriptsDir}/volume.sh output raise";
          on-scroll-down = "${scriptsDir}/volume.sh output lower";
        };
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "SpaceMono Nerd Font", "Noto Color Emoji";
        font-weight: bold;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: transparent;
      }

      #workspaces {
        background: ${colors.module-bg};
        margin: 0;
        padding: 0 4px;
        border-radius: 16px;
      }

      #workspaces button {
        padding: 0 8px;
        color: ${colors.main-fg};
        margin: 3px 2px;
        transition: all 0.3s ease;
      }

      #workspaces button.active {
        color: ${colors.accent};
        background: transparent;
      }

      #workspaces button:hover {
        background: ${colors.hover-bg};
        border-radius: 16px;
      }

      #window {
        background: ${colors.module-bg};
        padding: 0 15px;
        border-radius: 16px;
        color: ${colors.main-fg};
        margin: 0 5px;
      }

      #group-hardware {
        background: ${colors.module-bg};
        padding: 0 10px;
        border-radius: 16px;
      }

      /* Стилизация всех модулей внутри правого пузырька */
      #network, #bluetooth, #pulseaudio, #backlight, #battery, #clock {
        padding: 0 10px;
        color: ${colors.main-fg};
      }

      #clock.time {
        color: ${colors.accent};
      }

      #battery.critical {
        color: ${colors.accent};
      }
    '';
  };
}
