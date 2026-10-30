# Профиль ИБ (Цилла) на локальной модели: те же инструкция, скиллы, MCP,
# allow-list и инструменты, что у agy-sec, но мозг — gemma-4-12b в llama-server.
# Два клиента для сравнения:
#
#   opencode-sec   opencode с отдельным каталогом конфига (~/.opencode-security)
#   agy-sdk-sec    Google Antigravity SDK (LocalOpenAIAgentConfig) + свой REPL
#   llama-sec      поднять llama-server и подменить KV-кэш слота (см. llama-sec.sh)
#
# Параметры сервера — ../../../local-llm.nix, общие с сервисом загрузки `ai`.
#
# KV-снимки. Первый запуск клиента после ребилда прогревает кэш одним коротким
# запросом и сохраняет слот (`llama-sec save <клиент>-<хеш профиля>`). Дальше
# каждый запуск сначала восстанавливает снимок: инструкция, описания
# инструментов и скиллов уже посчитаны, модель отвечает без 30–40 с префилла.
# Хеш меняется вместе с промптом, устаревший снимок просто не используется.
# Совпадение кэша llama.cpp проверяет по токенам, а в имени снимка — сборка
# llama.cpp и аргументы сервера: снимок от другой сборки не встанет. Модель,
# заменённая по тому же пути, в имя не попадает: после такой замены удали
# снимки (`rm ~/.eva/llama-slots/*.bin`).
{ config, lib, pkgs, inputs, pkgsCuda, isNixOS ? true, ... }:

let
  ai = import ../../../lib.nix { inherit lib pkgs; };
  ecc = inputs.ecc.lib.mk { inherit pkgs lib; };
  inherit (ecc) payload;
  secTools = import ../tools.nix { inherit lib pkgs inputs pkgsCuda; };
  py = import ../py { inherit lib pkgs inputs pkgsCuda; };
  llm = import ../../../local-llm.nix { inherit pkgs; home = config.home.homeDirectory; };
  perms = import ../permissions.nix;
  semgrepMcp = import ../semgrep-mcp.nix { inherit pkgs; };
  json = pkgs.formats.json { };

  # Системная инструкция: GEMINI.md профиля + поправки на локальный запуск.
  prompt = pkgs.concatText "cilla-local.md" [ ../GEMINI.md ./LOCAL.md ];

  # Все скиллы agy-sec одним деревом: ECC (включая project-flake из модуля
  # badrabbit форка) + свои sec-audit-*.
  skills = pkgs.symlinkJoin {
    name = "agy-sec-skills";
    paths = [
      "${payload}/claude/skills"
      ../skills
    ];
  };

  ocDir = ".opencode-security";
  ocProvider = "llama";

  # permission.bash. Последнее совпавшее правило побеждает, а порядок ключей
  # в JSON задаёт сортировка Nix, и она здесь как раз нужная: «cmd *» идёт
  # раньше «cmd * -*», а та раньше «cmd -*» и «cmd -флаг *».
  # Проверено `opencode-sec debug config`.
  # Флаги префикса повторять нельзя: `--metrics=off … --metrics=on`.
  pinnedFlags = c: map (t: lib.head (lib.splitString "=" t))
    (lib.filter (lib.hasPrefix "--") (lib.splitString " " c));
  commandRules = c: risky0: let risky = lib.unique (risky0 ++ pinnedFlags c); in
    { ${c} = "allow"; "${c} *" = "allow"; }
    // lib.listToAttrs (lib.concatMap
      (r: [ (lib.nameValuePair "${c} ${r}*" "ask") (lib.nameValuePair "${c} * ${r}*" "ask") ])
      risky);
  readRules = c: { bare ? true, flags ? [ ], solo ? [ ] }:
    { ${c} = "allow"; "${c} -*" = "ask"; }
    // lib.optionalAttrs bare { "${c} *" = "allow"; "${c} * -*" = "ask"; }
    // lib.listToAttrs (lib.concatMap
      (f: [
        (lib.nameValuePair "${c} ${f}" "allow")
        (lib.nameValuePair "${c} ${f} *" "allow")
        (lib.nameValuePair "${c} ${f} * -*" "ask")
        (lib.nameValuePair "${c} ${f} -*" "ask") # второй флаг сразу за первым
      ] ++ lib.optionals (lib.hasPrefix "--" f) [
        (lib.nameValuePair "${c} ${f}=*" "allow")
        (lib.nameValuePair "${c} ${f}=* -*" "ask")
      ])
      flags)
    // lib.genAttrs (map (s: "${c} ${s}") solo) (_: "allow");
  bashRules = lib.foldl' (a: b: a // b) { "*" = "ask"; }
    (lib.mapAttrsToList commandRules perms.commands ++ lib.mapAttrsToList readRules perms.read);

  # Глобальные вопросы поверх allow-list. opencode проверяет каждую команду
  # из строки отдельно, поэтому цепочки и конвейеры разбирать не надо, но
  # перенаправления и подстановки приходят вместе с командой и проходят по
  # «cmd *». OPENCODE_PERMISSION вливается после всех конфигов, новые ключи
  # встают в конец и побеждают любое allow выше.
  ocGuards = builtins.toJSON {
    bash = lib.genAttrs [
      "*>*" "*<*" "*$*" "*`*"                     # перенаправления, переменные, подстановки
      # Шаблоны сверяются с сырым текстом, а оболочка склеит `-e"x"ec`,
      # `-\exec` и `-{e,}xec` обратно в -exec: такие строки не разбираем.
      "*'*" "*\"*" "*\\*" "*{*" "*}*"
      "/*" "* /*" "*=/*" "*,/*" "* -?/*" "*..*" "*~*"  # пути вне проекта, в т.ч. -o/… и fmt=/…
      "*http://*" "*https://*"                       # сеть
      "*.git/*" "*.direnv*" "*.vscode/*"             # исполняемые потом конфиги
      "*file:///*" "*dir:/*" "*sbom:/*"
      "*.env*"                                     # секреты — только с вопросом
    ] (_: "ask");
  };

  ocConfig = json.generate "opencode-sec.json" {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    share = "disabled";
    snapshot = false; # не копировать рабочее дерево клиента в ~/.local/share
    formatter = false; # форматтеры после правок — исполнение чужого кода
    lsp = false; # LSP-серверы opencode докачивает из сети сам
    enabled_providers = [ ocProvider ];
    model = "${ocProvider}/${llm.model}";
    small_model = "${ocProvider}/${llm.model}";
    default_agent = "cilla";
    provider.${ocProvider} = {
      npm = "@ai-sdk/openai-compatible";
      name = "llama.cpp (локально)";
      options.baseURL = llm.baseUrl;
      models.${llm.model} = {
        name = "gemma-4-12b (llama.cpp)";
        tool_call = true;
        reasoning = true;
        limit = { context = llm.context; output = 16384; };
      };
    };
    agent.cilla = {
      mode = "primary";
      description = "Цилла — аудит безопасности на локальной модели";
      # Своя инструкция вместо провайдерской: она идёт первой в промпте,
      # раньше блока окружения (cwd, дата), и кэшируется между проектами.
      prompt = "{file:${prompt}}";
    };
    mcp.semgrep = {
      type = "local";
      command = [ semgrepMcp.command ] ++ semgrepMcp.args;
      environment = semgrepMcp.env;
      enabled = true;
    };
    permission = {
      # .env и его варианты — только с вопросом (как в умолчаниях opencode)
      read = { "*" = "allow"; "*.env" = "ask"; "*.env.*" = "ask"; "*.env.example" = "allow"; };
      list = "allow";
      glob = "allow";
      grep = "allow";
      skill = "allow";
      todowrite = "allow";
      lsp = "deny";
      edit = "ask";
      bash = bashRules;
      task = "deny"; # субагенты на 12B только жгут контекст
      webfetch = "ask";
      websearch = "ask";
      external_directory = "ask";
      doom_loop = "ask";
      "semgrep_*" = "allow";
    };
  };

  sdkConfig = json.generate "agy-sdk-sec.json" {
    inherit (llm) model baseUrl;
    instructions = [ "${prompt}" ];
    skillsPaths = [ "${skills}" ];
    mcp.semgrep = semgrepMcp;
    inherit (perms) commands read;
    compactAt = llm.context * 3 / 4;
    stateDir = "~/.agy-security/sdk"; # рядом с agy-sec, тоже 700
  };

  # Имя KV-снимка: клиент + хеш всего, что попадает в префикс промпта,
  # включая сам клиент (новая версия — другие описания инструментов) и сборку
  # llama.cpp (формат снимка у разных версий разный).
  snapName = client: drv: cfg: "${client}-${lib.substring 0 12
    (builtins.hashString "sha256" (builtins.unsafeDiscardStringContext "${drv}${cfg}${prompt}${skills}${llm.llama}${llm.argsString}"))}";

  llamaSec = pkgs.writeShellApplication {
    name = "llama-sec";
    runtimeInputs = [ pkgs.curl pkgs.jq pkgs.coreutils pkgs.findutils pkgs.gnused pkgs.systemd ];
    text = ''
      LLAMA_SERVER=${llm.llama}/bin/llama-server
      LLAMA_ARGS=(${llm.argsString})
      LLAMA_URL=${lib.escapeShellArg llm.baseUrl}
      SLOT_DIR=${lib.escapeShellArg llm.slotDir}
      MODEL=${lib.escapeShellArg llm.model}
      SYSTEM_UNIT=${lib.escapeShellArg llm.systemUnit}
      UNIT_PROPS=(${lib.escapeShellArgs (lib.mapAttrsToList (k: v: "--property=${k}=${v}") llm.userHardening)})
    '' + builtins.readFile ./llama-sec.sh;
  };

  # Подготовка модели перед запуском клиента. $1 — имя снимка, дальше —
  # команда прогрева (тот же клиент, один короткий запрос).
  # LLAMA_SEC_SKIP=1 — ничего не трогать (так зовётся и сам прогрев).
  # Прогрев идёт в пустом временном каталоге: конфиг, скиллы и файлы
  # проверяемого репо в него не попадают, а префикс промпта от cwd не зависит.
  warmTimeout = 300;
  prepare = ''
    prepare_llm() {
      [ -z "''${LLAMA_SEC_SKIP:-}" ] || return 0
      local snap="$1"; shift
      ${if isNixOS then ''
        llama-sec up
        llama-sec restore "$snap" 2>/dev/null && return 0
        echo "llama-sec: новый промпт профиля — прогреваю KV-кэш (~1 мин, один раз)…" >&2
        local rc=0
        (
          warm=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/llama-sec-warm.XXXXXX")
          trap 'rm -rf -- "$warm"' EXIT # и на Ctrl-C
          cd "$warm"
          LLAMA_SEC_SKIP=1 timeout ${toString warmTimeout} "$@" </dev/null >/dev/null 2>&1
        ) || rc=$?
        if [ "$rc" -eq 0 ]; then
          llama-sec save "$snap" || true
        else
          echo "llama-sec: прогрев не удался (код $rc), работаю без снимка" >&2
        fi
      '' else ''
        # Без NixOS-сервиса: llama-server поднимают руками на ${llm.baseUrl}.
        curl -sf --max-time 2 ${lib.escapeShellArg "${lib.removeSuffix "/v1" llm.baseUrl}/health"} >/dev/null \
          || echo "агент ждёт llama-server на ${llm.baseUrl} — он не отвечает" >&2
      ''}
    }
  '';

  # Окружение агента: безопасный git и сканеры без сети (../permissions.nix).
  agentEnv = ''
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "export ${k}='${lib.replaceStrings [ "'" ] [ "'\\''" ] v}'\n") perms.env)}
    export SEMGREP_SEND_METRICS="''${SEMGREP_SEND_METRICS:-off}"
  '';

  warmPrompt = "Ответь одним словом: готова.";

  opencodeSec = pkgs.writeShellApplication {
    name = "opencode-sec";
    runtimeInputs = [ pkgs.opencode pkgs.curl pkgs.coreutils ] ++ lib.optional isNixOS llamaSec ++ secTools.tools;
    text = agentEnv + prepare + ''
      export OPENCODE_CONFIG=${ocConfig}
      export OPENCODE_CONFIG_DIR="$HOME/${ocDir}"
      # opencode.json и .opencode/ проверяемого репо перекрыли бы наш конфиг
      # вплоть до bash: allow — не читаем их вовсе.
      export OPENCODE_DISABLE_PROJECT_CONFIG=1
      export OPENCODE_PURE=1                     # без внешних плагинов
      export OPENCODE_DISABLE_EXTERNAL_SKILLS=1  # без ~/.agents, .agents и .claude/skills
      export OPENCODE_DISABLE_CLAUDE_CODE=1      # без ~/.claude/{CLAUDE.md,skills}
      export OPENCODE_DISABLE_AUTOUPDATE=1
      export OPENCODE_DISABLE_LSP_DOWNLOAD=1
      export OPENCODE_DISABLE_MODELS_FETCH=1
      export OPENCODE_PERMISSION=${lib.escapeShellArg ocGuards}
      # Своя БД сессий: беседы аудита не смешиваются с обычным opencode.
      umask 077
      mkdir -p "$HOME/${ocDir}/state"
      chmod 700 "$HOME/${ocDir}/state"
      export OPENCODE_DB="$HOME/${ocDir}/state/opencode.db"
      prepare_llm ${snapName "opencode" pkgs.opencode ocConfig} opencode run ${lib.escapeShellArg warmPrompt}
      exec opencode "$@"
    '';
  };

  sdkSec = pkgs.writeShellApplication {
    name = "agy-sdk-sec";
    runtimeInputs = [ pkgs.curl pkgs.coreutils ] ++ lib.optional isNixOS llamaSec ++ secTools.tools;
    text = agentEnv + prepare + ''
      # массив, а не функция: прогрев идёт через timeout, а он функций не видит
      sdk=(${py.antigravity-sdk}/bin/python -I ${./agy_sdk_sec.py} --config ${sdkConfig})
      prepare_llm ${snapName "sdk" py.antigravity-sdk sdkConfig} "''${sdk[@]}" -p ${lib.escapeShellArg warmPrompt}
      exec "''${sdk[@]}" "$@"
    '';
  };
  # Python с Antigravity SDK для своих скриптов: agy-sdk-python script.py
  sdkPython = pkgs.writeShellScriptBin "agy-sdk-python" ''exec ${py.antigravity-sdk}/bin/python "$@"'';
in
{
  home.packages = [ opencodeSec sdkSec sdkPython ] ++ lib.optional isNixOS llamaSec;

  # Каталог конфига opencode-sec: только скиллы. Сам конфиг — OPENCODE_CONFIG
  # из стора; каталог мутабельный, opencode кладёт туда свои package.json.
  home.file."${ocDir}/skills" = ai.recursive "${skills}";
}
