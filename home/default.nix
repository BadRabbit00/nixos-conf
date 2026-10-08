{ config, pkgs, ... }:

{
  home.username = "BadRabbit";
  home.homeDirectory = "/home/BadRabbit";

  home.stateVersion = "24.05";
  home.enableNixpkgsReleaseCheck = false;

  gtk.gtk4.theme = config.gtk.theme;

  imports = [
    ./generic-linux.nix
    ./secrets.nix
    ./desktop/default.nix
    ./shell/default.nix
    ./terminal/kitty.nix
    ./programs/default.nix
    ./programs/ssh/default.nix
    ./theme/default.nix
  ];

  programs.home-manager.enable = true;
}
