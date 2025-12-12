{ config, pkgs, ... }:

{
  home.username = "BadRabbit";
  home.homeDirectory = "/home/BadRabbit";

  home.stateVersion = "24.05";

  imports = [
    ./desktop/default.nix
    ./shell/default.nix
    ./terminal/hyper.nix
    ./programs/default.nix
    ./theme/default.nix
  ];

  programs.home-manager.enable = true;
}
