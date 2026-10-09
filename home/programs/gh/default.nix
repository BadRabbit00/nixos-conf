{ ... }:

# GitHub CLI (`gh`) — декларативно, через Home Manager.
#
# ПОЧЕМУ так, а не `nix-env -iA gh` и не `gh config set`:
#   * `programs.gh.settings` генерирует ~/.config/gh/config.yml как симлинк в
#     store — конфиг воспроизводим и откатывается вместе с генерацией HM.
#   * `programs.gh.hosts` мы НАМЕРЕННО не задаем. Эта опция линкует
#     ~/.config/gh/hosts.yml на read-only путь в /nix/store, после чего
#     `gh auth login` падает, а сам токен попал бы в world-readable store.
#     Авторизация остается императивной по природе: `gh auth login` пишет
#     hosts.yml/keyring сам. Секреты в репозиторий не едут.
{
  programs.gh = {
    enable = true;

    settings = {
      # В programs.ssh уже прописан github.com -> ~/.ssh/id_github,
      # поэтому clone/push идут по ssh, без паролей в URL.
      git_protocol = "ssh";
      editor = "nvim"; # programs.neovim.defaultEditor = true
      prompt = "enabled";

      aliases = {
        co = "pr checkout";
        pv = "pr view";
        prs = "pr list";
        rv = "pr review";
        ci = "run list";
      };
    };

    # Credential helper для тех https-ремоутов, что всё же просочатся
    # (gist, submodules, скрипты CI). Берет токен из gh auth, а не с диска.
    gitCredentialHelper.enable = true;
  };
}
