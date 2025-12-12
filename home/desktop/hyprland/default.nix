{ pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
  };

  home.packages = with pkgs; [
    swww
    mpvpaper # Required for video wallpapers
    hyprlock
    hypridle
    grim
    slurp
    wl-clipboard
  ];

  xdg.configFile."hypr/hyprlock.conf".source = ./hyprlock.conf;
  
  # Copy local wallpaper to VM
  xdg.configFile."hypr/wallpaper.mp4".source = ../../wallpapers/wallpaper.mp4;
}
