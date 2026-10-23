# MCP-серверы для claude-code, codex и agy: одно объявление — все агенты.
#
#   graphify — память кода. Граф лежит в ./graphify-out/graph.json в корне
#              проекта, значит переживает и смену сессии, и смену агента:
#              что построил один, читает другой.
#   zep      — обычная память. Удалённый сервер Zep, OAuth, ключ в конфиг не
#              кладётся вообще.
#   context7 — живая документация библиотек. Ключ приезжает из sops в рантайме.
#   colab    — удалённая песочница: агент пишет и исполняет ячейки в открытом
#              ноутбуке Colab. Пока только для agy (см. agyFrag ниже).
{ config, lib, pkgs, inputs, isNixOS ? true, ... }:

let
  ai = import ../lib.nix { inherit lib pkgs; };

  # В nixpkgs graphify собран голым: сам graphify-mcp есть, а питоновской
  # либы mcp нет — сервер падает с ModuleNotFoundError на первом же запуске.
  # Доливаем ровно один экстра, без остального обвеса.
  graphify = pkgs.graphify.overridePythonAttrs (old: {
    dependencies = old.dependencies ++ old.optional-dependencies.mcp;
  });

  # Ключу context7 в /nix/store не место: стор мировой-читаемый. Поэтому в
  # декларации его нет — обёртка читает расшифрованный sops-ом файл в момент
  # старта сервера. Нет ключа — работаем с рейт-лимитом, а не молча врём.
  context7 = pkgs.writeShellApplication {
    name = "context7-mcp-sops";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      keyfile=${if isNixOS then "/run/secrets/context7_api_key" else lib.escapeShellArg "${config.sops.defaultSymlinkPath}/context7_api_key"}
      if [ -r "$keyfile" ]; then
        CONTEXT7_API_KEY="$(tr -d '\r\n' < "$keyfile")"
        export CONTEXT7_API_KEY
      else
        echo "context7: нет $keyfile — работаю без ключа, с рейт-лимитом" >&2
      fi
      exec ${pkgs.context7-mcp}/bin/context7-mcp "$@"
    '';
  };

  zepUrl = "https://api.getzep.com/mcp";

  # Замкнутый venv в сторе, собранный из uv.lock проекта. Подробности — в файле.
  colab = import ./colab-mcp.nix { inherit lib pkgs inputs; };

  json = (pkgs.formats.json { }).generate;

  # Одни и те же серверы, две разные анатомии конфигов.
  claudeServers = {
    graphify = {
      type = "stdio";
      command = "${graphify}/bin/graphify-mcp";
      args = [ ];
      env = { };
    };
    context7 = {
      type = "stdio";
      command = "${context7}/bin/context7-mcp-sops";
      args = [ ];
      env = { };
    };
    zep = {
      type = "http";
      url = zepUrl;
    };
  };

  codexFrag = json "mcp-codex.json" {
    graphify.command = "${graphify}/bin/graphify-mcp";
    context7.command = "${context7}/bin/context7-mcp-sops";
    zep.url = zepUrl;
  };

  # Antigravity сериализует этот файл через protojson, поэтому форма записи
  # повторяет ту, что пишет он сам ($typeName + command/args/env). Поля timeout
  # из документации Google здесь намеренно нет: наш venv уже собран в сторе и
  # стартует мгновенно, а лишний ключ рискует не пройти разбор protobuf.
  agyFrag = json "mcp-agy.json" {
    colab-mcp = {
      "$typeName" = "exa.cascade_plugins_pb.CascadePluginCommandTemplate";
      command = "${colab}/bin/colab-mcp";
      args = [ ];
      env = { };
    };
  };

  # Оба агента пишут свои конфиги сами: claude складывает туда кэши и счётчики,
  # codex — trust_level проектов. Владеть такими файлами через home.file значит
  # подсунуть агенту симлинк в стор и сломать ему запись. Поэтому не владеем, а
  # вливаем свой кусок (ai.mergeJson / ai.mergeToml), чужие ключи не трогаем.
  sync = pkgs.writeShellApplication {
    name = "ai-mcp-sync";
    runtimeInputs = ai.mergeInputs;
    text = ''
      # shellcheck disable=SC2016  # jq-выражения обязаны быть в одинарных кавычках
      # Codex: config.toml, комментарии в нём не переживают прогон.
      ${ai.mergeToml { file = ''"$HOME/${ai.roots.codex}/config.toml"''; frag = codexFrag;
                       expr = ".mcp_servers = ((.mcp_servers // {}) + $ours[0])"; }}
      # Antigravity CLI: путь выдран из бинаря (стрипнут, но строка на месте),
      # agy читает глобальные MCP отсюда, а НЕ из ~/.gemini/antigravity-cli/
      # рядом с settings.json и не из ~/.gemini/antigravity/ (конфиг IDE).
      ${ai.mergeJson { file = ''"$HOME/${ai.roots.agy}/mcp_config.json"''; frag = agyFrag;
                       expr = ".mcpServers = ((.mcpServers // {}) + $ours[0])"; }}
      echo "MCP разложены: graphify, zep, context7 -> codex; colab -> agy (claude — через ai-profiles-sync)"
    '';
  };
in
{
  # Claude получает те же серверы через профиль code (../profiles.nix):
  # вливаются в ~/.claude.json скриптом ai-profiles-sync.
  ai.profiles.code.mcp = claudeServers;

  home.packages = [
    graphify # сам CLI: без `graphify extract` графа не существует
    colab    # тот же бинарь, что прописан agy — удобно дёрнуть для диагностики
    sync     # перелить руками, не дожидаясь ребилда
  ];

  home.activation.aiMcpServers =
    lib.hm.dag.entryAfter [ "writeBoundary" ] "$DRY_RUN_CMD ${sync}/bin/ai-mcp-sync";
}
