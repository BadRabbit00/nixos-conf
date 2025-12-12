{ pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
  };

  home.packages = with pkgs; [
    swww
    hyprlock
    hypridle
    grim
    slurp
    wl-clipboard
  ];
}
