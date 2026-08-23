{ pkgs, ... }:

{
  users.users.BadRabbit = {
    isNormalUser = true;
    description = "BadRabbit";
    extraGroups = [ "networkmanager" "wheel" "video" "input" "docker" ];
    shell = pkgs.zsh;
    # initialPassword задаёт пароль ТОЛЬКО при первой установке (для уже существующего
    # юзера инертен). Для реальной защиты сгенерируй хэш и переключись на hashedPassword:
    #   mkpasswd -m sha-512
    # затем: hashedPassword = "<хэш>";  (или через sops: hashedPasswordFile = ...)
    initialPassword = "password";
  };

  # Enable Zsh globally so it can be used as a default shell
  programs.zsh.enable = true;

  # Android tools (adb/fastboot). programs.adb удалён в systemd 258 — uaccess-правила
  # для устройств теперь применяются автоматически, отдельная группа adbusers не нужна.
  environment.systemPackages = [ pkgs.android-tools ];

  # Security: Disable sudo password for wheel group (осознанный выбор для личного лэптопа).
  security.sudo.wheelNeedsPassword = false;
}
