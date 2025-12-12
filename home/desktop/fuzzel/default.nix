{ pkgs, ... }:

{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "${pkgs.kitty}/bin/kitty"; 
        layer = "overlay";
        width = 40;
        font = "SpaceMono Nerd Font:size=14";
      };
      colors = {
        background = "1e1e2eff";
        text = "cdd6f4ff";
        match = "f38ba8ff";
        selection = "585b70ff";
        selection-text = "cdd6f4ff";
        border = "f5c2e7ff";  # Bocchi Pink
      };
      border = {
        width = 2;
        radius = 10;
      };
    };
  };
}
