{ pkgs, ... }:

{
  home.packages = with pkgs; [
    swww
  ];

  home.file.".local/bin/wall.sh" = {
    source = ./wall.sh;
    executable = true;
  };

  # Если ты положишь сюда wall.png, он станет твоими обоями по умолчанию
  xdg.configFile."swww/wall.png" = {
    source = ./wall.png;
  };

  xdg.configFile."swww/templates".source = ./templates;
}
