{ pkgs, ... }:

{
  home.packages = with pkgs; [
    awww
  ];

  home.file.".local/bin/wall.sh" = {
    source = ./wall.sh;
    executable = true;
  };

  # Если ты положишь сюда wall.png, он станет твоими обоями по умолчанию
  xdg.configFile."awww/wall.png" = {
    source = ./wall.png;
  };

  xdg.configFile."awww/templates".source = ./templates;
}
