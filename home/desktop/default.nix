{ pkgs, ... }:

{
  imports = [
    ./hyprland/default.nix
    ./eww/default.nix
    ./fuzzel/default.nix
    ./swaync/default.nix
  ];
}
