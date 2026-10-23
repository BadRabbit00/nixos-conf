# Профиль «монтаж»: свой каталог ~/.claude-montage и обёртка `claude-montage`.
# Ни ECC, ни хуков, ни кодерских правил здесь нет; CLAUDE.md, скиллы и
# инструменты — только про видео. Логин отдельный: первый запуск попросит /login.
#
#   skills.nix     скиллы из 26 репозиториев, запинены по rev/hash
#   node-tools.nix Remotion, HyperFrames, Apify из npm-лока (node-tools/)
#   banner.md      памятка про Nix, вшивается в каждый SKILL.md
#   CLAUDE.md      Лилит-монтажёр
#   blender.nix    скиллы Blender (35), MCP-сервер mcp-for-blender и аддон в ~/.config/blender
#   ml-shell.nix   devShell montage-ml: whisperx, faster-whisper, uv для ACE-Step
#                  (nix develop ~/nixos-conf#montage-ml), торч в PATH агента не кладём
#
# Инструменты попадают в PATH только внутри claude-montage: скрипты скиллов
# зовут их по имени, а окружение при этом запинено flake.lock. MCP-серверов
# нет намеренно: FilmCraft и EffectCraft управляются своим CLI/JSON-каналом.
{ lib, pkgs, pkgsCuda, ... }:

let
  nodeTools = import ./node-tools.nix { inherit lib pkgs; };

  # Библиотеки, которые импортируют скрипты скиллов (color-correct, pixel2motion,
  # claude-video, OpenMontage). Тяжёлые ML-стеки (torch, whisperx, mediapipe,
  # diffusers) не включены: скиллы, которым они нужны, скажут об этом сами;
  # для них место — отдельный devShell с CUDA, а не PATH агента.
  python = pkgs.python3.withPackages (ps: with ps; [
    numpy scipy pillow opencv4 librosa soundfile playwright pyyaml requests matplotlib
  ]);

  # whisper.cpp с CUDA (sm_120 покрыт, бинарь приходит из cache.nixos-cuda.org).
  whisper = pkgsCuda.whisper-cpp;
  # Blender с Cycles на CUDA; GUI-вариант для моделирования ставит home/programs.
  # Оба из pkgsCuda (home/generic-linux.nix): так они приходят из CUDA-кэша.
  blender = pkgsCuda.blender;
in
{
  imports = [ ./blender.nix ]; # скиллы Blender, MCP-сервер и аддон

  ai.profiles.montage = {
    instructions = ./CLAUDE.md;
    skills = import ./skills.nix { inherit lib pkgs; };
    mcp = { };

    tools = [
      # видео/аудио/картинки
      pkgs.ffmpeg-full      # ffmpeg, ffprobe, ffplay со всеми кодеками и NVENC
      pkgs.mediainfo
      pkgs.sox
      pkgs.imagemagick      # magick, convert
      pkgs.exiftool
      pkgs.audiowaveform    # waveform PNG/JSON из аудио
      pkgs.yt-dlp
      pkgs.mkvtoolnix-cli   # mkvmerge, mkvextract
      # распознавание речи и очистка
      whisper               # whisper-cli, whisper-server; модели — whisper-cpp-download-ggml-model
      pkgs.piper-tts        # локальная озвучка (OpenMontage её и ждёт)
      pkgs.realesrgan-ncnn-vulkan # апскейл кадров
      pkgs.demucs-rs        # demucs: разделение на стемы (вокал, ударные, бас)
      pkgs.tesseract        # OCR субтитров и текста с кадров
      pkgs.handbrake        # HandBrakeCLI: пакетный транскод
      # графика и 3D
      pkgs.inkscape         # inkscape CLI: SVG-конвертация и экспорт
      pkgs.potrace          # растр -> вектор (pixel2motion)
      blender               # blender -b: headless-рендер, тот же пакет стоит как GUI
      pkgs.vhs              # запись терминала в GIF/MP4
      # программный рендер
      pkgs.nodejs
      pkgs.manim
      python
    ] ++ nodeTools.all;     # remotion, hyperframes, apify

    env = {
      # python-playwright (pixel2motion, claude-video) берёт браузеры из стора,
      # а не качает их в ~/.cache/ms-playwright.
      PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
      PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      # hyperframes/puppeteer: chromium из Nix, без скачивания.
      HYPERFRAMES_BROWSER_PATH = lib.getExe pkgs.chromium;
      PUPPETEER_SKIP_DOWNLOAD = "1";
    };
  };
}
