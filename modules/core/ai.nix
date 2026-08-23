{ config, pkgs, lib, ... }:

let
  # Единая CUDA-сборка llama-cpp. Собирается с AVX2 (AVX-512 на i9-14900HX выпилен Intel).
  cudaLlama = pkgs.llama-cpp.override { cudaSupport = true; };

  # Боевое хранилище моделей агента eva. Модели — вне Nix store (они огромные).
  # gemma-3n-E4B Q8 (~6.9GB) влезает в 8GB VRAM целиком (с -fa для экономии KV-кэша).
  evaModels = "/home/BadRabbit/.eva/models";
  gemmaModel = "${evaModels}/gemma-3n-E4B-it-Q8_0.gguf";
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
    systemd.services.llama-server = {
      description = "Llama.cpp Inference Server (CUDA) — gemma-3n-E4B";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        # OpenAI-совместимый эндпоинт для агента eva на 127.0.0.1:8080/v1.
        #   -ngl 999 : все слои в VRAM.  -fa on : flash-attention (экономит KV-кэш на 8GB).
        #   --jinja  : chat-шаблон модели (нужен для корректного форматирования/tool-calling).
        #   -c 4096  : контекст (подними, если хватит VRAM).  -t 12 : P-cores i9-14900HX.
        ExecStart = "${cudaLlama}/bin/llama-server -m ${gemmaModel} --host 127.0.0.1 --port 8080 -ngl 999 -fa on -c 4096 -t 12 --jinja";
        Restart = "on-failure";
        RestartSec = 5;
        User = "BadRabbit";
      };
    };
  };
}
