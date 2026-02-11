{ pkgs, ... }:

{
  home.packages = with pkgs; [
    swww
  ];

  home.file.".local/bin/wall.sh" = {
    source = ./wall.sh;
    executable = true;
  };

  xdg.configFile."swww/templates".source = ./templates;
}
