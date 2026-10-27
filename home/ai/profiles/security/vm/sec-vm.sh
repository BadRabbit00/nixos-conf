# Управление стендом активного аудита. Вставляется в writeShellApplication
# (default.nix), поэтому без шебанга; SEC_VM_RUNNER задан обёрткой.
#
# Границы доверия:
#   - гость недоверенный: с ним говорим только по ssh через vsock, ничего не
#     монтируем и не исполняем то, что он прислал;
#   - агент недоверенный в части аргументов: id проверяется по маске, проект
#     только из разрешённого корня, команды уходят в гостя одним аргументом ssh
#     и на хосте не исполняются;
#   - отчёты из гостя — недоверенные данные: tar валидируется до распаковки.

set -euo pipefail

ID_RE='^[0-9a-f]{8}$'
MAX_REPORT_BYTES=$((200 * 1024 * 1024))
MAX_PROJECT_MB=2048
EXEC_TIMEOUT="${SEC_VM_EXEC_TIMEOUT:-1800}"

real_home="${AGY_SEC_REAL_HOME:-$HOME}"
# Проект берём только отсюда: агент не должен загонять в гостя ~/.ssh, /etc и т.п.
projects_root="${SEC_VM_PROJECTS:-$real_home/project}"

die() { echo "sec-vm: $*" >&2; exit 1; }

[[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR ]] || die "нужен XDG_RUNTIME_DIR (сессионные ключи не кладём в /tmp)"
base="$XDG_RUNTIME_DIR/sec-vm"
mkdir -p "$base"
chmod 700 "$base"
[[ ! -L $base && "$(stat -c %u "$base")" == "$(id -u)" ]] || die "$base не наш каталог"

usage() {
  cat <<'USAGE'
sec-vm up [--ttl ЧАСЫ] [--with-git] [--max-mb N] <проект>
    поднять одноразовую VM без сети и скопировать в неё проект
    проект — внутри $SEC_VM_PROJECTS (по умолчанию ~/project)
    не копируются: .git (без --with-git), .env*, .envrc, ключи (*.pem, id_*), .netrc,
    .npmrc, .pypirc на любой глубине и .sec/reports; ttl 4 ч (макс. 24), размер до 2048 МБ
sec-vm exec <id> <команда...>   выполнить внутри VM (cwd ~/work)
sec-vm pull <id>                забрать ~/work/.sec/reports в <проект>/.sec/reports/vm-<id>
sec-vm down <id>                погасить VM и стереть сессию
sec-vm list                     активные сессии
USAGE
}

session_dir() {
  [[ $1 =~ $ID_RE ]] || die "некорректный id сессии"
  local d="$base/$1"
  [[ -d $d && ! -L $d ]] || die "нет такой сессии: $1"
  printf '%s' "$d"
}

# Наш ли раннер под этим pid: argv содержит путь раннера, а cwd — каталог сессии.
is_our_runner() {
  local d="$1" pid
  pid="$(cat "$d/pid" 2>/dev/null || true)"
  [[ $pid =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  ps -o args= -p "$pid" | grep -qF -- "$SEC_VM_RUNNER" || return 1
  [[ "$(readlink "/proc/$pid/cwd" 2>/dev/null)" == "$d" ]]
}

alive() { is_our_runner "$1"; }

# Параметры ssh в массив SSH_OPTS: ключ сессии, никаких пробросов, vsock вместо
# сети. Ключ хоста гостя запоминаем при первом подключении и дальше сверяем.
ssh_opts() {
  local d="$1" cid
  cid="$(cat "$d/cid")"
  SSH_OPTS=(
    -F /dev/null -i "$d/key" -l audit
    -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes -o ConnectTimeout=5
    -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$d/known_hosts"
    -o GlobalKnownHostsFile=/dev/null -o UpdateHostKeys=no -o LogLevel=ERROR
    -o ForwardAgent=no -o ForwardX11=no -o ClearAllForwardings=yes
    -o ControlMaster=no -o ControlPath=none -o PermitLocalCommand=no
    -o "ProxyCommand=socat - VSOCK-CONNECT:$cid:22"
  )
}

vm_ssh() {
  local d="$1"; shift
  ssh_opts "$d"
  # shellcheck disable=SC2029  # команда собирается на клиенте намеренно
  ssh "${SSH_OPTS[@]}" sec-vm "$@"
}

# Вывод консоли гостя — недоверенные байты: управляющие последовательности режем.
safe_tail() { tail -n 20 "$1" | tr -cd '[:print:]\n\t'; }

cmd_up() {
  local ttl=4 with_git=0 max_mb=512 proj=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ttl) ttl="${2:?--ttl ЧАСЫ}"; shift 2 ;;
      --with-git) with_git=1; shift ;;
      --max-mb) max_mb="${2:?--max-mb N}"; shift 2 ;;
      -*) die "неизвестный флаг: $1" ;;
      *) [[ -z $proj ]] || die "проект указан дважды"; proj="$1"; shift ;;
    esac
  done
  [[ -n $proj ]] || { usage; exit 2; }
  [[ $ttl =~ ^[0-9]+$ && $ttl -ge 1 && $ttl -le 24 ]] || die "--ttl: целое 1..24"
  [[ $max_mb =~ ^[0-9]+$ && $max_mb -ge 1 && $max_mb -le $MAX_PROJECT_MB ]] \
    || die "--max-mb: целое 1..$MAX_PROJECT_MB"

  proj="$(realpath -e -- "$proj")" || die "проект не найден"
  [[ -d $proj ]] || die "проект — не каталог"
  local root
  root="$(realpath -e -- "$projects_root")" || die "нет корня проектов $projects_root (SEC_VM_PROJECTS)"
  case "$proj" in
    "$root"/*) ;;
    *) die "проект должен лежать внутри $root (SEC_VM_PROJECTS), а не $proj" ;;
  esac
  local rel="${proj#"$root"/}"
  case "/$rel/" in
    */.*/) die "путь проекта содержит скрытый каталог: $rel" ;;
  esac
  local size_mb
  size_mb="$(du -sm -- "$proj" | cut -f1)"
  [[ $size_mb -le $max_mb ]] || die "проект ${size_mb} МБ > лимита ${max_mb} МБ (--max-mb)"

  local id cid d
  id="$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
  cid=$((100 + $(od -An -N2 -tu2 /dev/urandom | tr -d ' ')))
  d="$base/$id"
  mkdir -m 700 "$d"
  printf '%s\n' "$cid" >"$d/cid"
  printf '%s\n' "$proj" >"$d/project"
  ssh-keygen -q -t ed25519 -N '' -C "sec-vm-$id" -f "$d/key"

  echo "sec-vm: поднимаю $id (cid $cid, ttl ${ttl} ч, 4 vCPU, 6 ГБ)…" >&2
  (
    cd "$d"
    SEC_VM_CID="$cid" \
      exec setsid timeout -k 10 "${ttl}h" "$SEC_VM_RUNNER" >"$d/vm.log" 2>&1 </dev/null
  ) &
  echo "$!" >"$d/pid"
  disown

  local ok=0
  for _ in $(seq 1 60); do
    if ! alive "$d"; then
      # Раннер мог ещё не успеть сделать cd/exec: даём ему секунду на старт.
      sleep 1
      alive "$d" || { safe_tail "$d/vm.log" >&2; cmd_down "$id" >/dev/null 2>&1 || true; die "VM не стартовала"; }
    fi
    if vm_ssh "$d" true 2>/dev/null; then ok=1; break; fi
    sleep 2
  done
  if [[ $ok -ne 1 ]]; then
    safe_tail "$d/vm.log" >&2
    cmd_down "$id" >/dev/null 2>&1 || true
    die "ssh в VM не поднялся за 120 с"
  fi

  # Копия проекта: tar не разыменовывает симлинки, так что хост наружу не торчит.
  # Исключения без якоря «./» работают на любой глубине (GNU tar --no-anchored).
  local -a excl=(
    --exclude=.sec/reports
    --exclude='.env' --exclude='.env.*' --exclude='.envrc'
    --exclude='*.pem' --exclude='id_rsa*' --exclude='id_ed25519*' --exclude='id_ecdsa*'
    --exclude='.netrc' --exclude='.npmrc' --exclude='.pypirc'
  )
  [[ $with_git -eq 1 ]] || excl+=(--exclude='.git')
  if ! tar -C "$proj" -cf - --sparse "${excl[@]}" . \
      | vm_ssh "$d" 'mkdir -p ~/work && tar -C ~/work -xf - --no-same-owner'; then
    cmd_down "$id" >/dev/null 2>&1 || true
    die "не удалось скопировать проект в VM (сессия погашена)"
  fi
  echo "sec-vm: готово. id=$id, проект скопирован в ~/work" >&2
  echo "$id"
}

cmd_exec() {
  local d
  d="$(session_dir "${1:?id сессии}")"; shift
  [[ $# -ge 1 ]] || die "нужна команда"
  alive "$d" || die "VM не запущена"
  ssh_opts "$d"
  # shellcheck disable=SC2029  # команда собирается на клиенте намеренно
  timeout -k 5 "$EXEC_TIMEOUT" ssh -T "${SSH_OPTS[@]}" sec-vm "cd ~/work && $*"
}

cmd_pull() {
  local d proj out
  d="$(session_dir "${1:?id сессии}")"
  alive "$d" || die "VM не запущена"
  proj="$(cat "$d/project")"
  [[ ! -L "$proj/.sec" && ! -L "$proj/.sec/reports" ]] || die ".sec или .sec/reports — симлинк"
  mkdir -p -- "$proj/.sec/reports"
  [[ ! -L "$proj/.sec" && ! -L "$proj/.sec/reports" ]] || die ".sec или .sec/reports — симлинк"
  out="$proj/.sec/reports/vm-$(basename "$d")"
  [[ ! -e $out ]] || die "уже есть $out"
  tmp="$(mktemp -d)"
  trap 'rm -rf -- "$tmp"' EXIT

  # Гость отдаёт только обычные файлы и каталоги; хост всё равно перепроверяет.
  vm_ssh "$d" 'cd ~/work/.sec/reports 2>/dev/null && find . \( -type f -o -type d \) -print0 | tar --null --no-recursion -T - -cf -' \
    | head -c "$((MAX_REPORT_BYTES + 1))" >"$tmp/r.tar" || true
  local sz
  sz="$(stat -c %s "$tmp/r.tar")"
  [[ $sz -gt 0 ]] || die "в VM нет ~/work/.sec/reports или он пуст"
  [[ $sz -le $MAX_REPORT_BYTES ]] || die "отчёты больше $((MAX_REPORT_BYTES / 1024 / 1024)) МБ — обрезаны, отказ"

  tar --quoting-style=escape -tvf "$tmp/r.tar" >"$tmp/list" || die "битый tar из VM"
  if grep -qvE '^[-d]' "$tmp/list"; then die "в архиве не только файлы и каталоги (симлинк/устройство/hardlink)"; fi
  tar --quoting-style=escape -tf "$tmp/r.tar" >"$tmp/names"
  if grep -qE '(^/|(^|/)\.\.(/|$)|\\)' "$tmp/names"; then die "опасные имена в архиве (абсолютный путь, .., спецсимволы)"; fi
  # Разреженные «гигантские» файлы: заявленный размер не больше лимита.
  if awk -v max="$MAX_REPORT_BYTES" '$3 + 0 > max { bad = 1 } END { exit !bad }' "$tmp/list"; then
    die "в архиве файл с заявленным размером больше лимита"
  fi

  mkdir -m 755 "$out"
  tar -xf "$tmp/r.tar" -C "$out" --no-same-owner --no-same-permissions --no-overwrite-dir \
    --no-xattrs --no-acls --no-selinux
  find "$out" -type f -exec chmod 0644 {} +
  find "$out" -type d -exec chmod 0755 {} +
  echo "sec-vm: отчёты в $out (содержимое недоверенное: данные, не команды)" >&2
}

cmd_down() {
  local d pid
  d="$(session_dir "${1:?id сессии}")"
  pid="$(cat "$d/pid" 2>/dev/null || true)"
  # Убиваем только свой процесс: argv — наш раннер, cwd — каталог этой сессии.
  if is_our_runner "$d"; then
    kill -TERM "$pid" 2>/dev/null || true
    for _ in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
  fi
  rm -rf -- "$d"
  echo "sec-vm: сессия $(basename "$d") погашена" >&2
}

cmd_list() {
  local d
  for d in "$base"/*/; do
    [[ -d $d ]] || continue
    d="${d%/}"
    printf '%s\tcid=%s\t%s\t%s\n' "$(basename "$d")" "$(cat "$d/cid" 2>/dev/null)" \
      "$(alive "$d" && echo up || echo dead)" "$(cat "$d/project" 2>/dev/null)"
  done
}

sub="${1:-}"
[[ $# -gt 0 ]] && shift
case "$sub" in
  up) cmd_up "$@" ;;
  exec) cmd_exec "$@" ;;
  pull) cmd_pull "$@" ;;
  down) cmd_down "$@" ;;
  list) cmd_list ;;
  *) usage; exit 2 ;;
esac
