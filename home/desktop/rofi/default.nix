{ pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    # Мы будем использовать кастомный файл темы, который будет генерировать matugen
    theme = "~/.cache/matugen/rofi.rasi";
  };
}
