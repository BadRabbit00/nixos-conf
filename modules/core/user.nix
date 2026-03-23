{ pkgs, ... }:

{
  users.users.BadRabbit = {
    isNormalUser = true;
    description = "BadRabbit";
    extraGroups = [ "networkmanager" "wheel" "video" "input" "adbusers" ];
    shell = pkgs.zsh;
    initialPassword = "password";
  };

  # Enable Zsh globally so it can be used as a default shell
  programs.zsh.enable = true;

  # Security: Disable sudo password for wheel group
  security.sudo.wheelNeedsPassword = false;
}
