{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      name = "SpaceMono Nerd Font";
      size = 14;
    };
    settings = {
      # Window layout
      window_padding_width = 15;
      placement_strategy = "center";
      hide_window_decorations = "yes";
      
      # Инфернальная палитра
      foreground = "#ac7e7c"; # Твой dusty rose
      background = "#0c0c0c"; # Твоя бездна
      selection_foreground = "#0c0c0c";
      selection_background = "#611a1c";
      
      # Cursor
      cursor = "#d33637";
      cursor_text_color = "#0c0c0c";
      
      # URL
      url_color = "#d33637";
      
      # Borders
      active_border_color = "#d33637";
      inactive_border_color = "#351212";
      bell_border_color = "#d33637";
      
      # Tabs
      active_tab_foreground = "#0c0c0c";
      active_tab_background = "#d33637";
      inactive_tab_foreground = "#ac7e7c";
      inactive_tab_background = "#242424";
      tab_bar_background = "#0c0c0c";

      # Opacity / Blur
      background_opacity = "0.9";

      # ANSI Colors (Dark and Red tones)
      color0 = "#0c0c0c"; # black
      color8 = "#351212"; # bright black
      color1 = "#d33637"; # red
      color9 = "#d33637"; # bright red
      color2 = "#611a1c"; # green -> dark red
      color10 = "#744c4c"; # bright green -> dusty red
      color3 = "#ac7e7c"; # yellow -> dusty rose
      color11 = "#7b615d"; # bright yellow
      color4 = "#351212"; # blue -> deep red
      color12 = "#403736"; # bright blue
      color5 = "#611a1c"; # magenta -> dark red
      color13 = "#ac7e7c"; # bright magenta
      color6 = "#744c4c"; # cyan -> dusty red
      color14 = "#7b615d"; # bright cyan
      color7 = "#ac7e7c"; # white
      color15 = "#ffffff"; # bright white
    };
  };
}
