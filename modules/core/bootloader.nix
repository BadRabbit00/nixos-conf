{ pkgs, ... }:

let
  # Наша новая инфернальная тема, собранная из ассетов KawaiiGRUB
  # Но перерожденная в черном цвете с твоим логотипом.
  infernal-theme = pkgs.stdenv.mkDerivation {
    pname = "infernal-grub-theme";
    version = "2.0";
    src = ./grub-theme;
    installPhase = ''
      mkdir -p $out
      cp -r ./* $out/
    '';
  };
in
{
  # --- Параметры Загрузчика (GRUB) ---
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    theme = infernal-theme;
    gfxmodeEfi = "1920x1080";
    gfxmodeBios = "1920x1080";
    splashImage = null;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;

  # --- Отключаем Plymouth и тихую загрузку ---
  # Ты просил shell-загрузку, значит никаких масок.
  boot.plymouth.enable = false;

  # Параметры ядра для максимально информативной загрузки
  boot.kernelParams = [
    "boot.shell_on_fail=true"
    "loglevel=7" # Видим всё
  ];
}
