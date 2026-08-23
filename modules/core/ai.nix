{ config, pkgs, lib, ... }:

let
  # Единая CUDA-сборка llama-cpp. Собирается с AVX2 (AVX-512 на i9-14900HX выпилен Intel).
  cudaLlama = pkgs.llama-cpp.override { cudaSupport = true; };

  # Реальная модель под 8GB VRAM. gemma-3n-E4B Q8 (~6.9GB) влезает в видеопамять.
  # ВНИМАНИЕ: путь ведёт в ~/models-tmp — при желании перенеси модели в постоянное место.
  gemmaModel = "/home/BadRabbit/models-tmp/gemma-3n-E4B-it-GGUF/gemma-3n-E4B-it-Q8_0.gguf";
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
        # -ngl 999: все слои в VRAM. Для gemma-3n-E4B Q8 на 8GB может потребоваться
        #           тюнинг (-ngl поменьше / -c поменьше), если упрётся в память.
        # -t 12   : физические P-cores i9-14900HX.
        ExecStart = "${cudaLlama}/bin/llama-server -m ${gemmaModel} --host 127.0.0.1 --port 8080 -ngl 999 -c 4096 -t 12";
        Restart = "on-failure";
        RestartSec = 5;
        User = "BadRabbit";
      };
    };
  };
}
