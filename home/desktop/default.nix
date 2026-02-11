{ pkgs, ... }:

{
  imports = [
    ./hyprland/default.nix
    ./swaync/default.nix
    ./waybar/default.nix
    ./rofi/default.nix
    ./swww/default.nix
  ];
}
