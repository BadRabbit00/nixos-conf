# Системная часть storytold Crafting Apps (сами приложения — в home/programs/craftapps).
# Нужна только ради шрифтов: текстовые инструменты PhotoCraft/EffectCraft читают
# /usr/share/fonts напрямую, минуя fontconfig, а на NixOS такого пути нет.
# Модуль флейка с linkFonts (по умолчанию true) включает fonts.fontDir и линкует
# /usr/share/fonts -> /run/current-system/sw/share/X11/fonts, так что всё из
# fonts.packages становится видно приложениям. Ни одного app здесь не включаем:
# пользовательские программы живут в Home Manager, environment.systemPackages
# остаётся пустым.
{ inputs, ... }:

{
  imports = [ inputs.craftapps.nixosModules.default ];

  programs.craftapps = {
    enable = true;
    linkFonts = true;
  };
}
