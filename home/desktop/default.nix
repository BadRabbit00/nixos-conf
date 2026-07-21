{ pkgs, ... }:

{
  imports = [
    ./niri/default.nix
    ./swaync/default.nix
    ./waybar/default.nix
    ./rofi/default.nix
    ./awww/default.nix
  ];
}
