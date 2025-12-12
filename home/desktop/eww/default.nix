{ pkgs, ... }:

{
  programs.eww = {
    enable = true;
    configDir = ./config;
  };

  home.packages = [ pkgs.cava ];
}
