{ pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
  };

  home.packages = with pkgs; [
    hyprlock
    hypridle
    grim
    slurp
    wl-clipboard
  ];

  xdg.configFile."hypr/hyprlock.conf".source = ./hyprlock.conf;
}
