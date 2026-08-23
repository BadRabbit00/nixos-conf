{ pkgs, config, ... }:

{
  time.timeZone = "Asia/Almaty";

  # Catppuccin: явно фиксируем поведение, чтобы убрать warning о будущем авто-энроле.
  # autoEnable = false сохраняет текущее состояние (порты не подключаются автоматически),
  # enable = true — новый глобальный тумблер (без autoEnable ничего не темится).
  catppuccin.enable = true;
  catppuccin.autoEnable = false;

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true; # Deduplicate identical files
    builders-use-substitutes = true;
    
    # Optimization for faster downloads
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://catppuccin.cachix.org"
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "catppuccin.cachix.org-1:noSAt829IPhS9XNoW+uX96t8829FdyxG9WzT7Y9i3u4="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMBZ6nHMZdAYhPbMI1SrxSSTZ6g6hS7E="
    ];

    # Ограничение параллелизма: до 2 пакетов одновременно по 12 ядер на каждый.
    # Бережём 24 ядра + 32GB от свапа на тяжёлых C++/CUDA-сборках (llama-cpp).
    max-jobs = 2;
    cores = 12;
    http-connections = 50;
    stalled-download-timeout = 90;
    download-attempts = 10;
    trusted-users = [ "root" "BadRabbit" "@wheel" ];
  };

  # Garbage collection to save disk space
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  # Fonts configuration
  fonts.packages = with pkgs; [
    nerd-fonts.space-mono
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
  ];

  # Legion specific support
  # boot.extraModulePackages для lenovo-legion-module живёт в legion.nix (не дублируем).
  environment.systemPackages = with pkgs; [
    lenovo-legion
  ];

  # Allow unfree packages (needed for Chrome, VS Code, etc.)
  nixpkgs.config.allowUnfree = true;
  environment.sessionVariables.NIXPKGS_ALLOW_UNFREE = "1";

  # zRAM - RAM compression for heavy workloads
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 60;
    priority = 100;
  };

  # Udev rules for backlight permissions
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/sh -c 'chgrp video /sys/class/backlight/%k/brightness && chmod g+w /sys/class/backlight/%k/brightness'"
  '';
}
