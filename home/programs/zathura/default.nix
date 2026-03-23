{ pkgs, ... }:

{
  programs.zathura = {
    enable = true;
    options = {
      # Selection
      selection-clipboard = "clipboard";
      
      # Aesthetic / Colors (Infernal Blood Theme)
      recolor = true; # Force dark mode for all documents
      recolor-keephue = true;
      
      default-bg = "#0c0c0c";
      default-fg = "#ac7e7c";
      
      statusbar-bg = "#0c0c0c";
      statusbar-fg = "#ac7e7c";
      
      inputbar-bg = "#0c0c0c";
      inputbar-fg = "#d33637";
      
      notification-bg = "#0c0c0c";
      notification-fg = "#d33637";
      
      notification-error-bg = "#0c0c0c";
      notification-error-fg = "#d33637";
      
      notification-warning-bg = "#0c0c0c";
      notification-warning-fg = "#d33637";
      
      highlight-color = "#d33637";
      highlight-active-color = "#611a1c";
      
      completion-bg = "#0c0c0c";
      completion-fg = "#ac7e7c";
      
      completion-highlight-bg = "#d33637";
      completion-highlight-fg = "#0c0c0c";
      
      index-bg = "#0c0c0c";
      index-fg = "#ac7e7c";
      
      index-active-bg = "#d33637";
      index-active-fg = "#0c0c0c";
      
      recolor-lightcolor = "#0c0c0c"; # Background in dark mode
      recolor-darkcolor = "#ac7e7c";  # Text in dark mode
      
      render-loading = true;
      render-loading-bg = "#0c0c0c";
      render-loading-fg = "#ac7e7c";

      # GUI adjustments
      guioptions = "none"; # No scrollbars, no menu
      font = "JetBrainsMono Nerd Font 12";
    };
    
    # Format plugins
    package = pkgs.zathura.withPlugins (p: with p; [
      zathura_djvu
      zathura_pdf_mupdf
      zathura_cb
    ]);
  };
}
