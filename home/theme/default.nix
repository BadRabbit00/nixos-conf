{ pkgs, ... }:

{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic"; # Черные курсоры лучше подходят к бездне
    size = 24;
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
  
  # Qt theming to match GTK
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "gtk2";
  };
}
