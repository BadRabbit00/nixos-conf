{ config, pkgs, ... }:

{
  home.username = "BadRabbit";
  home.homeDirectory = "/home/BadRabbit";

  home.stateVersion = "26.05";

  gtk.gtk4.theme = config.gtk.theme;

  imports = [
    ./desktop/default.nix
    ./shell/default.nix
    ./terminal/kitty.nix
    ./programs/default.nix
    ./programs/ssh/default.nix
    ./theme/default.nix
  ];

  programs.home-manager.enable = true;
}
