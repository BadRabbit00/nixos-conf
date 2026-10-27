# Локальная LLM: одна точка правды для llama-server.
#
# Читают оба слоя: системный сервис специализации `ai` (modules/core/ai.nix,
# стартует при загрузке) и команда `llama-sec` из профиля ИБ (поднимает тот же
# сервер в обычной загрузке). Аргументы обязаны совпадать: снимок KV-кэша слота
# (`--slot-save-path`) восстанавливается только в сервер с той же моделью,
# тем же типом KV и тем же контекстом.
#
# gemma-4-12b Q4_K_M (7.4 GB) + 128k контекста не влезают в 8 GB VRAM целиком:
# `--fit on` сам оставляет на CPU столько слоёв, сколько нужно. KV — q8_0
# (у gemma4 40 из 48 слоёв со скользящим окном 1024, глобальные — с 1 KV-головой,
# так что 128k дёшевы). Кэш промптов и SWA-чекпоинты живут в RAM (`--cache-ram`).
{ pkgs, home }:

rec {
  # Та же CUDA-сборка, что в modules/core/ai.nix: одна деривация на систему.
  llama = pkgs.llama-cpp.override { cudaSupport = true; };

  host = "127.0.0.1";
  port = 8090; # 8080 занят docker-проектами (krafta-web)
  baseUrl = "http://${host}:${toString port}/v1";

  # Имя модели в OpenAI API (`-a`): его пишут в конфиги клиентов.
  model = "gemma-4-12b";
  modelFile = "${home}/.eva/models/gemma-4-12b-it-uncensored-GGUF/gemma-4-12b-it-uncensored-Q4_K_M.gguf";
  context = 131072; # gemma4.context_length из GGUF

  # Снимки KV-кэша слотов (`llama-sec save/restore`); вне стора, они большие.
  slotDir = "${home}/.eva/llama-slots";

  args = [
    "-m" modelFile
    "-a" model
    "--host" host
    "--port" (toString port)
    "-c" (toString context)
    "-np" "1"            # один слот: снимок KV — это снимок слота 0
    "-fa" "on"
    "-ctk" "q8_0"
    "-ctv" "q8_0"
    "--fit" "on"         # лишние слои — в RAM
    "--cache-ram" "16384" # кэш промптов в RAM, MiB
    "-cms" "1024"        # SWA-чекпоинты чаще: префикс (инструкция + инструменты) переиспользуется точнее
    "-t" "8"             # P-cores i9-14900HX
    "--jinja"            # chat-шаблон модели, нужен для tool-calling
    "--slot-save-path" slotDir
    # Только API для локальных клиентов: без web UI, CORS — лишь свой origin
    # и без credentials: чужая страница в браузере не прочтёт ответы. Слепой
    # POST (в т.ч. /slots) CORS не останавливает, а ключ API SDK-клиент
    # передать не умеет (GemmaEndpoint — только base_url): остаточный риск.
    "--no-webui"
    "--cors-origins" "http://${host}:${toString port}"
    "--no-cors-credentials"
  ];

  argsString = pkgs.lib.escapeShellArgs args;

  # Системный сервис загрузки `ai`: `llama-sec` его ждёт, а не дублирует.
  systemUnit = "llama-server.service";

  # Песочница для обоих юнитов. Что работает и в user-менеджере без root:
  # KV-снимки — беседы, поэтому UMask 0077.
  userHardening = {
    UMask = "0077";
    NoNewPrivileges = "yes";
    LockPersonality = "yes";
    RestrictRealtime = "yes";
    RestrictSUIDSGID = "yes";
    SystemCallArchitectures = "native";
  };

  # Системному юниту — ещё и изоляция ФС и сети. /dev не прячем: CUDA нужны
  # /dev/nvidia*. ProtectClock не ставим: он неявно включает DeviceAllow, и
  # cgroup-фильтр закрыл бы GPU (DevicePolicy=auto становится closed).
  # MemoryDenyWriteExecute ломает JIT CUDA.
  systemHardening = userHardening // {
    ProtectSystem = "strict";
    ProtectHome = "read-only"; # модель — в ~/.eva/models
    ReadWritePaths = slotDir; # создаёт tmpfiles (modules/core/ai.nix)
    PrivateTmp = "yes";
    ProtectKernelModules = "yes";
    ProtectKernelTunables = "yes";
    ProtectKernelLogs = "yes";
    ProtectControlGroups = "yes";
    ProtectHostname = "yes";
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    RestrictNamespaces = "yes";
    RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX AF_NETLINK";
    IPAddressDeny = "any";
    IPAddressAllow = "localhost";
  };
}
