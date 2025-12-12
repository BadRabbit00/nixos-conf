{ pkgs, ... }:

{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  gtk = {
    enable = true;
    
    theme = {
      package = pkgs.catppuccin-gtk.override {
        accents = [ "pink" ]; # Bocchi Pink Accent
        size = "standard";
        tweaks = [ "rimless" "black" ]; # Black background for OLED vibes
        variant = "mocha";
      };
      name = "Catppuccin-Mocha-Standard-Pink-Dark";
    };

    iconTheme = {
      package = pkgs.tela-circle-icon-theme;
      name = "Tela-circle-pink"; # Pink folders
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
