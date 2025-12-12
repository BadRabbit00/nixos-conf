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
      hide_window_decorations = "yes"; # No title bar
      
      # Colors (Catppuccin Mocha)
      foreground = "#cdd6f4";
      background = "#1e1e2e";
      selection_foreground = "#1e1e2e";
      selection_background = "#f5e0dc";
      
      # Cursor
      cursor = "#f5e0dc";
      cursor_text_color = "#1e1e2e";
      
      # URL
      url_color = "#f5e0dc";
      
      # Borders
      active_border_color = "#f5c2e7"; # Bocchi Pink
      inactive_border_color = "#6c7086";
      bell_border_color = "#f9e2af";
      
      # Tabs
      active_tab_foreground = "#11111b";
      active_tab_background = "#cba6f7";
      inactive_tab_foreground = "#cdd6f4";
      inactive_tab_background = "#181825";
      tab_bar_background = "#11111b";

      # Opacity / Blur
      background_opacity = "0.85";
      # Note: Blur is controlled by Hyprland, not Kitty itself on Linux usually, 
      # but we set opacity here so Hyprland can blur it.
    };
  };
}
