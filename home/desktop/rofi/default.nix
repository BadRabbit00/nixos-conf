{ pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    # Используем нашу новую статичную кровавую тему
    theme = ./theme.rasi;
  };
}
