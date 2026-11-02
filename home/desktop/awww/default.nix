{ pkgs, ... }:

let
  # Демон смены обоев: новая случайная картинка на каждый экран раз в 5 минут.
  # niri берётся из PATH сессии (система на NixOS, /usr/bin на Arch).
  wall-cycle = pkgs.writeShellApplication {
    name = "wall-cycle";
    runtimeInputs = with pkgs; [ awww jq coreutils findutils ];
    text = builtins.readFile ./wall-cycle.sh;
  };
in
{
  home.packages = with pkgs; [
    awww
    wall-cycle
  ];

  home.file.".local/bin/wall.sh" = {
    source = ./wall.sh;
    executable = true;
  };

  # Если ты положишь сюда wall.png, он станет твоими обоями по умолчанию
  xdg.configFile."awww/wall.png" = {
    source = ./wall.png;
  };

  # Коллекция для wall-cycle: все *.png отсюда участвуют в ротации.
  xdg.configFile."awww/wallpapers".source = ./wallpapers;

  xdg.configFile."awww/templates".source = ./templates;
}
