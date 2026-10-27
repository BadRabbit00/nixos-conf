# llama-sec: llama-server с моделью ИБ-профиля и подмена KV-кэша слота.
# Шапку (LLAMA_SERVER, LLAMA_ARGS, LLAMA_URL, SLOT_DIR, MODEL, SYSTEM_UNIT,
# UNIT_PROPS — свойства песочницы user-юнита) подставляет Nix.
#
#   llama-sec               поднять сервер (если не поднят) и вернуть последний снимок KV
#   llama-sec up            только поднять сервер
#   llama-sec restore NAME  загрузить снимок NAME в слот 0
#   llama-sec save NAME     сохранить слот 0 в снимок NAME
#   llama-sec list          снимки в $SLOT_DIR
#   llama-sec status        кто держит порт, какая модель
#   llama-sec stop          остановить сервер, поднятый этой командой
#
# В обычной загрузке сервер стартует transient user-юнитом `llama-sec`
# (journalctl --user -u llama-sec). В загрузке `ai` его уже держит системный
# llama-server.service с теми же аргументами: тогда команда его не трогает,
# только подменяет KV-кэш.

UNIT=llama-sec
HEALTH="${LLAMA_URL%/v1}/health"
SLOTS="${LLAMA_URL%/v1}/slots/0"

die() { echo "llama-sec: $*" >&2; exit 1; }

# Именно llama-server: /health отдаёт JSON {"status":"ok"}, а не любой 200.
healthy() { curl -sf --max-time 2 "$HEALTH" 2>/dev/null | jq -e '.status == "ok"' >/dev/null 2>&1; }

port_taken() { curl -s -o /dev/null --max-time 2 "${LLAMA_URL%/v1}/" 2>/dev/null; }

served_model() {
  curl -sf --max-time 2 "$LLAMA_URL/models" | jq -r '.data[0].id // empty' 2>/dev/null
}

check_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || die "имя снимка: только [A-Za-z0-9._-], получено «$1»"
}

check_model() {
  local m
  m=$(served_model) || m=
  [ "$m" = "$MODEL" ] || die "на ${LLAMA_URL} уже другой сервер (модель «${m:-?}»), а нужна $MODEL"
}

# Ждать, пока сервер владельца $1 (user|system) догрузит модель: пока она
# грузится, /health отвечает 503, а порт уже занят.
wait_healthy() {
  local scope="$1" unit="$2"
  for _ in $(seq 1 180); do
    healthy && { check_model; return 0; }
    if [ "$scope" = system ]; then
      case "$(systemctl show -p ActiveState --value "$unit" 2>/dev/null)" in
        active|activating) ;;
        *) break ;;
      esac
    else
      systemctl --user is-active --quiet "$unit" || break
    fi
    sleep 1
  done
  if [ "$scope" = system ]; then
    journalctl -u "$unit" -n 30 --no-pager >&2 || true
  else
    journalctl --user -u "$unit" -n 30 --no-pager >&2 || true
  fi
  die "сервер не поднялся"
}

up() {
  if healthy; then check_model; return 0; fi
  # Загрузка `ai`: системный сервис стартует вместе с системой и ещё может
  # грузить модель — второй сервер на тот же порт не поднимаем, ждём его.
  local state
  state=$(systemctl show -p ActiveState --value "$SYSTEM_UNIT" 2>/dev/null || true)
  if [ "$state" = active ] || [ "$state" = activating ]; then
    echo "llama-sec: жду $SYSTEM_UNIT (модель грузится)…" >&2
    wait_healthy system "$SYSTEM_UNIT"
    return 0
  fi
  if port_taken && ! systemctl --user is-active --quiet "$UNIT"; then
    die "порт ${LLAMA_URL%/v1} занят чем-то, что не llama-server"
  fi
  mkdir -p "$SLOT_DIR"
  chmod 700 "$SLOT_DIR" # в KV — содержимое бесед
  if ! systemctl --user is-active --quiet "$UNIT"; then
    systemctl --user reset-failed "$UNIT" >/dev/null 2>&1 || true
    echo "llama-sec: запускаю $MODEL (первая загрузка ~10 с)…" >&2
    systemd-run --user --unit="$UNIT" --collect --quiet \
      --description="llama-server ($MODEL) для ИБ-профиля" \
      "${UNIT_PROPS[@]}" \
      "$LLAMA_SERVER" "${LLAMA_ARGS[@]}" \
      || systemctl --user is-active --quiet "$UNIT" \
      || die "не удалось запустить юнит $UNIT" # второй клиент мог успеть первым
  fi
  wait_healthy user "$UNIT"
}

slot_action() { # action name
  local out
  out=$(curl -sf --max-time 120 -X POST "$SLOTS?action=$1" \
        -H 'content-type: application/json' \
        -d "$(jq -cn --arg f "$2.bin" '{filename: $f}')") || return 1
  jq -e '.error | not' >/dev/null <<<"$out" || return 1
  jq -r '"llama-sec: \(.id_slot // 0): \(.n_saved // .n_restored // 0) токенов (\(.filename // ""))"' <<<"$out" >&2
}

restore() {
  check_name "$1"
  [ -f "$SLOT_DIR/$1.bin" ] || return 1
  slot_action restore "$1"
}

save() {
  check_name "$1"
  slot_action save "$1" || die "не удалось сохранить слот (занят генерацией?)"
}

latest() {
  [ -d "$SLOT_DIR" ] || return 0
  find "$SLOT_DIR" -maxdepth 1 -name '*.bin' -printf '%T@ %f\n' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2 | sed 's/\.bin$//'
}

cmd="${1:-default}"
case "$cmd" in
  default)
    up
    snap=$(latest)
    if [ -n "$snap" ]; then
      restore "$snap" || echo "llama-sec: снимок $snap не встал (модель или параметры другие?)" >&2
    else
      echo "llama-sec: снимков нет — их создаёт первый запуск opencode-sec / agy-sdk-sec" >&2
    fi
    ;;
  up) up ;;
  restore) [ $# -eq 2 ] || die "usage: llama-sec restore NAME"; up; restore "$2" || die "снимок $2 не встал" ;;
  save) [ $# -eq 2 ] || die "usage: llama-sec save NAME"; healthy || die "сервер не запущен"; save "$2" ;;
  list) [ -d "$SLOT_DIR" ] || exit 0; find "$SLOT_DIR" -maxdepth 1 -name '*.bin' -printf '%TY-%Tm-%Td %TH:%TM  %s  %f\n' 2>/dev/null | sort -r ;;
  status)
    if healthy; then
      echo "up: $LLAMA_URL, модель $(served_model)"
      systemctl --user is-active --quiet "$UNIT" && echo "владелец: user-юнит $UNIT" || echo "владелец: не llama-sec (системный llama-server.service?)"
    else
      echo "down: $LLAMA_URL"
    fi
    ;;
  stop)
    if systemctl --user is-active --quiet "$UNIT"; then
      systemctl --user stop "$UNIT"
    else
      echo "llama-sec: юнит $UNIT не запущен; системный сервер загрузки ai не трогаю" >&2
    fi
    ;;
  -h|--help|help)
    cat <<'EOF'
llama-sec               поднять сервер (если не поднят) и вернуть последний снимок KV
llama-sec up            только поднять сервер
llama-sec restore NAME  загрузить снимок NAME в слот 0
llama-sec save NAME     сохранить слот 0 в снимок NAME
llama-sec list          снимки KV
llama-sec status        кто держит порт, какая модель
llama-sec stop          остановить сервер, поднятый этой командой
EOF
    ;;
  *) die "неизвестная команда «$cmd» (llama-sec help)" ;;
esac
