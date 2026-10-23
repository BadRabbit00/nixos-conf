# storytold Crafting Apps — pure-Rust клоны Adobe-пакета (https://github.com/storytold).
# Пакеты приходят из inputs.craftapps (olafkfreund/nix-craftapps): официальные
# прибилженные бинари с GitHub releases, autoPatchelf под Nix-glibc, Vulkan/Wayland/
# X11/D-Bus на RUNPATH. Рендер — wgpu, поэтому на Arch оборачиваем в gpuWrap (nixGL,
# Intel iGPU); на NixOS gpuWrap — identity.
#
# Шрифты: текстовые инструменты ищут их ТОЛЬКО в /usr/share/fonts (не fontconfig).
# На NixOS этот каталог делает modules/core/craftapps.nix; на Arch он есть сам.
#
# Каждое приложение даёт GUI `<app>` и CLI `<app>-cli` (у CLI есть `mcp`-подкоманда).
{ pkgs, inputs, gpuWrap, ... }:

let
  craft = inputs.craftapps.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = map gpuWrap [
    craft.photocraft   # Photoshop: слои, PSD, ретушь
    craft.filmcraft    # Premiere: нелинейный видеомонтаж
    craft.effectcraft  # After Effects: моушн-графика и композитинг
  ];
}
