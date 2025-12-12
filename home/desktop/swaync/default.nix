{ pkgs, ... }:

{
  home.packages = [ pkgs.swaynotificationcenter ];
  
  xdg.configFile."swaync/config.json".source = ./config.json;
  xdg.configFile."swaync/style.css".source = ./style.css;
}
