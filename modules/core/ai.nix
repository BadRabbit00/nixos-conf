{ pkgs, ... }:

let
  # Модель, аргументы и CUDA-сборка — общие с командой `llama-sec` профиля ИБ
  # (home/ai/local-llm.nix): иначе её снимок KV-кэша не встанет в этот сервер.
  # Модели — вне Nix store (они огромные), в ~/.eva/models.
  llm = import ../../home/ai/local-llm.nix { inherit pkgs; home = "/home/BadRabbit"; };
  cudaLlama = llm.llama;
in
{
  environment.systemPackages = [
    # Бинарь доступен ВСЕГДА (в обеих генерациях) для ручного запуска: llama-server -m ...
    cudaLlama

    # Инструментарий Rust для агентов (cargo, rustc). Для проектов предпочитай nix develop.
    pkgs.cargo
    pkgs.rustc
    pkgs.rustfmt
    pkgs.clippy
  ];

  # --- Автозапуск llama-server ТОЛЬКО в специализации ai-compute ---
  # В обычной генерации сервиса нет: GPU свободен, модель не грузится в фон.
  # Загрузись в поколение "ai-compute" из меню GRUB, чтобы поднять сервер автоматически.
  # Мержится со специализацией ai, объявленной в nvidia.nix.
  specialisation.ai.configuration = {
    # Каталог KV-снимков до старта песочницы (ReadWritePaths требует, чтобы он
    # был). tmpfiles, а не install от root: тот не пойдёт по подложенному
    # пользователем симлинку. В снимках — содержимое бесед, поэтому 0700.
    systemd.tmpfiles.settings."10-llama-slots".${llm.slotDir}.d = {
      user = "BadRabbit";
      group = "users";
      mode = "0700";
    };

    systemd.services.llama-server = {
      description = "Llama.cpp Inference Server (CUDA) — ${llm.model}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        # OpenAI-совместимый эндпоинт на ${llm.baseUrl}, модель без инструкций:
        # системный промпт приносит клиент. `llama-sec` подменяет KV-кэш слота
        # на прогретый ИБ-профиль (см. home/ai/local-llm.nix).
        ExecStart = "${cudaLlama}/bin/llama-server ${llm.argsString}";
        Restart = "on-failure";
        RestartSec = 5;
        User = "BadRabbit";
      } // llm.systemHardening;
    };
  };
}
