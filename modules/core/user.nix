{ pkgs, ... }:

{
  users.users.BadRabbit = {
    isNormalUser = true;
    description = "BadRabbit";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
  };

  # Enable Zsh globally so it can be used as a default shell
  programs.zsh.enable = true;
}
