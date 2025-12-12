{ pkgs, ... }:

{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "${pkgs.kitty}/bin/kitty"; # Temporary, will switch to Hyper
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
        border = "b4befeff";
      };
      border = {
        width = 2;
        radius = 10;
      };
    };
  };
}
