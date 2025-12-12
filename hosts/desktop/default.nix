{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/bootloader.nix
    ../../modules/core/network.nix
    ../../modules/core/user.nix
    ../../modules/core/system.nix
    ../../modules/core/program.nix
    ../../modules/core/audio.nix
    ../../modules/hyprland/default.nix
  ];
  
  system.stateVersion = "24.05";
}
