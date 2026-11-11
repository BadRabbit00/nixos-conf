{ config, lib, pkgs, ... }:

let
  # Catppuccin Mocha с красным акцентом под "Infernal Blood".
  catppuccinKvantum = pkgs.catppuccin-kvantum.override {
    accent = "red";
    variant = "mocha";
  };
in
{
  home = {
    pointerCursor = {
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic"; # Черные курсоры лучше подходят к бездне
      size = 24;
    };

    # HM по умолчанию делает `xrdb -merge` под защитой лишь `[[ -v DISPLAY ]]`.
    # Если DISPLAY задан, а X-сервера нет (niri без xwayland-satellite, мёртвый
    # ssh-forward), xrdb завершается с 1, а activate работает под `set -e` и
    # молча пропускает reloadSystemd и warrenSync. mkForce заменяет onChange из
    # modules/xresources.nix: сбой xrdb становится предупреждением.
    file.${config.xresources.path}.onChange = lib.mkForce ''
      if [[ -v DISPLAY ]]; then
        ${lib.getExe pkgs.xrdb} -merge ${config.xresources.path} \
          || echo "warning: xrdb cannot reach DISPLAY=$DISPLAY, .Xresources not applied" >&2
      fi
    '';

    packages = [
      catppuccinKvantum
      pkgs.kdePackages.qtstyleplugin-kvantum  # движок Kvantum для Qt6
      pkgs.libsForQt5.qtstyleplugin-kvantum   # движок Kvantum для Qt5
    ];
  };

  gtk = {
    enable = true;
    
    theme = {
      package = pkgs.catppuccin-gtk.override {
        accents = [ "red" ]; # Меняем розовый на красный
        size = "standard";
        tweaks = [ "rimless" "black" ]; # Black background for OLED vibes
        variant = "mocha";
      };
      name = "Catppuccin-Mocha-Standard-Red-Dark";
    };

    iconTheme = {
      package = pkgs.tela-circle-icon-theme;
      name = "Tela-circle-red"; # Красные папки
    };

    font = {
      name = "SpaceMono Nerd Font";
      size = 11;
    };
  };
  
  # Qt theming через Kvantum (современно, темит и Qt5, и Qt6 — без gtk2-костылей).
  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";
  };


  # Активная тема Kvantum + симлинк самой темы в ~/.config/Kvantum для надёжного поиска.
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=catppuccin-mocha-red
  '';
  xdg.configFile."Kvantum/catppuccin-mocha-red".source =
    "${catppuccinKvantum}/share/Kvantum/catppuccin-mocha-red";
}
