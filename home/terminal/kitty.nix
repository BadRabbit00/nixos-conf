{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      name = "CommitMono Nerd Font"; # Более четкий и "механический" шрифт
      size = 13;
    };
    
    # Темы и плагины (Kittens)
    shellIntegration.enableZshIntegration = true;

    settings = {
      # --- Визуал ---
      window_padding_width = 15;
      placement_strategy = "center";
      hide_window_decorations = "yes";
      confirm_os_window_close = 0;
      background_opacity = "0.85";
      
      # Курсор и его анимация
      cursor_shape = "beam";
      cursor_beam_thickness = 1.5;
      cursor_blink_interval = 0.5;
      cursor_stop_blinking_after = "15.0";
      
      # Прокрутка
      scrollback_lines = 10000;
      wheel_scroll_multiplier = "5.0";
      touch_scroll_multiplier = "1.0";
      
      # Колокольчик (отключаем звук, оставляем визуальный)
      enable_audio_bell = "no";
      visual_bell_duration = "0.1";
      visual_bell_color = "#d33637";

      # --- Цвета (Твоя кровавая бездна) ---
      foreground = "#ac7e7c";
      background = "#0c0c0c";
      selection_foreground = "#0c0c0c";
      selection_background = "#611a1c";
      
      url_color = "#d33637";
      url_style = "curly"; # Волнистая линия под ссылками

      # Границы
      active_border_color = "#d33637";
      inactive_border_color = "#351212";
      
      # ANSI цвета (для полноценной поддержки CLI приложений)
      color0 = "#0c0c0c";
      color8 = "#351212";
      color1 = "#d33637";
      color9 = "#d33637";
      color2 = "#611a1c";
      color10 = "#744c4c";
      color3 = "#ac7e7c";
      color11 = "#7b615d";
      color4 = "#351212";
      color12 = "#403736";
      color5 = "#611a1c";
      color13 = "#ac7e7c";
      color6 = "#744c4c";
      color14 = "#7b615d";
      color7 = "#ac7e7c";
      color15 = "#ffffff";
    };

    # --- Горячие клавиши Kitty ---
    keybindings = {
      # Навигация по вкладкам
      "ctrl+shift+t" = "new_tab";
      "ctrl+shift+q" = "close_tab";
      "ctrl+shift+l" = "next_tab";
      "ctrl+shift+h" = "previous_tab";
      
      # Kittens: Hints (Открытие ссылок и путей)
      "alt+f" = "kitten hints --type path --program -"; # Выбрать путь и вставить в терминал
      "alt+u" = "kitten hints --type url";             # Открыть ссылку
      "alt+p" = "kitten hints --type hash --program -"; # Выбрать хеш (git) и вставить

      # Копирование/Вставка
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";

      # Управление размером шрифта
      "ctrl+plus" = "change_font_size all +2.0";
      "ctrl+minus" = "change_font_size all -2.0";
      "ctrl+0" = "restore_font_size";

      # Скроллинг
      "shift+page_up" = "scroll_page_up";
      "shift+page_down" = "scroll_page_down";
    };

    extraConfig = ''
      # Поддержка символов для отрисовки графики (icat)
      allow_remote_control yes
      listen_on unix:/tmp/kitty

      # Настройка размытия (для Hyprland)
      background_blur 1
    '';
  };
}
