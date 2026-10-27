# Что ИБ-профиль запускает без подтверждения: общий источник для agy-sec
# (permissions.allow), opencode-sec (permission.bash) и agy-sdk-sec (policy
# run_command). Всё, что не подошло, спрашивается у человека.
#
#   commands  префикс командной строки (слова целиком), дальше любые аргументы,
#             кроме начинающихся с токенов из `risky`. Сканеры — только в
#             офлайн-форме: флаги, отключающие сеть, входят в сам префикс, а
#             повторить их дальше (`--metrics=on`, `--offline=false`) клиенты
#             не дают — флаги префикса добавляются в `risky` автоматически.
#             Источник у syft/grype — точный (`dir:.`), иначе они сами
#             пойдут за образом в docker/registry.
#   read      читающие утилиты: аргументы без флагов или с флагами из `flags`
#             (за ними можно продолжать) и `solo` (только сам флаг).
#             `bare = false` — позиционные аргументы только после флага из `flags`
#             (`git branch NAME` создаёт ветку).
#   env       окружение агента: git не запускает fsmonitor, хуки, пейджер,
#             подпись и драйверы из .gitattributes (GIT_ATTR_SOURCE — пустое
#             дерево); сканеры не обновляют базы сами.
#
# Поверх этого клиенты сами отклоняют цепочки, перенаправления, подстановки,
# пути вне проекта (`/…`, `..`, `~`, в том числе склеенные `-o/…`, `fmt=/…`),
# URL, `.git/`, `.envrc` и `.env`; у agy-sec — только префиксы.
# Это эвристика поверх текста команды, а не песочница: недоверенное дерево
# (архив, чужой .git) аудируй в `sec-vm`, ему allow-list не нужен.
# Не в списке (спрашиваются): rg, git grep, sort, uniq, jq (исполняют, пишут
# или читают произвольные файлы флагами), pip-audit и npm audit (без сети не
# работают), snyk-agent-scan inspect (запускает MCP-серверы из конфига).
let
  remoteSources = [ "registry:" "docker:" "podman:" "oci-" "singularity:" "http" "--from" ];
  # Go-шаблон из проверяемого репо задаёт содержимое отчёта целиком.
  templates = [ "-t" "--template" ];
in
{
  commands = {
    # гейт и стенд (свои обёртки, сами проверяют аргументы)
    "sec-scan" = [ ];
    "sec-vm" = [ ];
    # секреты
    "gitleaks git" = [ "--report-template" ];
    "gitleaks dir" = [ "--report-template" ];
    "gitleaks version" = [ ];
    "trufflehog git file://. --no-verification" = [ ];
    "trufflehog filesystem . --no-verification" = [ ];
    "trufflehog --version" = [ ];
    # SAST: правила только локальные, без реестра semgrep
    "semgrep scan --metrics=off" = [
      "p/" "r/" "s/" "auto" "http" "--config=p/" "--config=r/" "--config=s/"
      "--config=auto" "--config=http" "-cp/" "-cr/" "-cs/" "-cauto" "-chttp"
      "--pro" "--secrets"
    ];
    "bandit" = [ ];
    # SCA / SBOM: без скачивания баз и образов
    "trivy fs --skip-db-update --skip-java-db-update --skip-check-update --offline-scan" = remoteSources ++ templates;
    "trivy config --skip-check-update" = remoteSources ++ templates;
    "osv-scanner scan source --offline" = [ "--download-offline-databases" ];
    "syft scan dir:." = remoteSources ++ templates;
    "grype dir:." = remoteSources ++ templates; # GRYPE_DB_AUTO_UPDATE=false — в окружении
    "grype sbom:.sec/reports/sbom.cdx.json" = remoteSources ++ templates;
    "cargo-audit audit --no-fetch" = [ ];
    # MCP: только статические анализаторы, без запуска и подключения к серверам
    "mcp-scanner --analyzers yara,readiness,prompt_defense,schema" = [
      "remote" "stdio" "config" "known-configs" "--server-url" "--stdio"
    ];
    "mcp-scanner --help" = [ ];
    "snyk-agent-scan --help" = [ ];
    # git — только чтение
    "git log --no-ext-diff --no-textconv" = [ "--output" "--ext-diff" "--textconv" "--show-signature" ];
    "git show --no-ext-diff --no-textconv" = [ "--output" "--ext-diff" "--textconv" "--show-signature" ];
    "git ls-files" = [ ];
    "git status" = [ ];
    "git rev-parse" = [ ];
    "git rev-list" = [ ];
    "git check-ignore" = [ ];
    # find — предикатов много, поэтому наоборот: опасные под запретом
    "find" = [
      "-exec" "-ok" "-delete" "-fprint" "-fls" "-files0-from" "-L" "-follow" "-H"
    ];
    "mkdir -p .sec/reports" = [ ];
    "mkdir -p .sec" = [ ];
  };

  read = {
    cat.flags = [ "-n" "-A" ];
    ls.flags = [ "-l" "-a" "-A" "-la" "-lh" "-lah" "-R" "-1" "-d" "-t" ];
    head.flags = [ "-n" "-c" ];
    tail.flags = [ "-n" "-c" ];
    wc.flags = [ "-l" "-w" "-c" "-m" ];
    grep.flags = [
      # без -r: рекурсия вычитала бы и .env — по дереву ищет инструмент grep клиента
      "-n" "-i" "-l" "-c" "-E" "-F" "-w" "-v" "-I" "-H" "-h" "-o" "-s" "-e"
      "-A" "-B" "-C" "--include" "--exclude" "--exclude-dir"
    ];
    cut.flags = [ "-d" "-f" "-c" "-b" ];
    tr.flags = [ "-d" "-s" "-c" ];
    du.flags = [ "-s" "-h" "-sh" "-a" "-d" ];
    file.flags = [ "-b" "-i" "--mime-type" ];
    stat.flags = [ "-c" "--format" ];
    echo.flags = [ "-n" ];
    printf.flags = [ ];
    which.flags = [ ];
    date.flags = [ "-u" "-I" "-R" ];
    pwd.flags = [ ];
    true.flags = [ ];
    "git branch" = {
      bare = false;
      flags = [
        "-l" "--list" "-a" "--all" "-r" "--remotes"
        "--contains" "--no-contains" "--merged" "--no-merged"
      ];
      solo = [ "-v" "-vv" "--verbose" "--show-current" ];
    };
  };

  env = {
    GIT_CONFIG_COUNT = "7";
    GIT_CONFIG_KEY_0 = "core.fsmonitor";
    GIT_CONFIG_VALUE_0 = "false";
    GIT_CONFIG_KEY_1 = "core.hooksPath";
    GIT_CONFIG_VALUE_1 = "/dev/null";
    GIT_CONFIG_KEY_2 = "core.pager";
    GIT_CONFIG_VALUE_2 = "cat";
    GIT_CONFIG_KEY_3 = "log.showSignature"; # иначе git log зовёт gpg.program из конфига репо
    GIT_CONFIG_VALUE_3 = "false";
    # …и на случай --show-signature: программы проверки подписи — заглушка
    GIT_CONFIG_KEY_4 = "gpg.program";
    GIT_CONFIG_VALUE_4 = "false";
    GIT_CONFIG_KEY_5 = "gpg.ssh.program";
    GIT_CONFIG_VALUE_5 = "false";
    GIT_CONFIG_KEY_6 = "gpg.x509.program";
    GIT_CONFIG_VALUE_6 = "false";
    # Атрибуты — из пустого дерева: .gitattributes репо не включит filter.*,
    # textconv и diff-драйверы, которые git status/log иначе запускают.
    GIT_ATTR_SOURCE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904";
    GIT_PAGER = "cat"; # сильнее pager.<cmd> из конфига репо
    PAGER = "cat";
    GIT_TERMINAL_PROMPT = "0";
    # сканеры не ходят в сеть сами
    GRYPE_DB_AUTO_UPDATE = "false";
    GRYPE_CHECK_FOR_APP_UPDATE = "false";
    SYFT_CHECK_FOR_APP_UPDATE = "false";
  };
}
