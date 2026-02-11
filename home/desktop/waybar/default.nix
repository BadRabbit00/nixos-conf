{ pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = builtins.readFile ./style.css;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "hyprland/workspaces" "hyprland/submap" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "network" "cpu" "memory" "tray" ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
        };

        "clock" = {
          format = "{:%H:%M:%S}";
          format-alt = "{:%A, %B %d, %Y}";
          interval = 1;
        };

        "cpu" = {
          format = "CPU: {usage}%";
        };

        "memory" = {
          format = "RAM: {}%";
        };

        "pulseaudio" = {
          format = "{volume}% {icon}";
          format-muted = "MUTED";
          format-icons = {
            default = [ "" "" "" ];
          };
        };
      };
    };
  };
}
