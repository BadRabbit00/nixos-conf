# Меняет обои раз в INTERVAL секунд (по умолчанию 5 минут).
# На старте ставит через awww случайную картинку из ~/.config/awww/wallpapers
# на каждый выход niri, затем по таймеру обновляет все выходы, не повторяя
# на одном экране ту картинку, что на нём уже висит.

WALL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/awww/wallpapers"
TRANSITION=(--transition-step 255)  # мгновенно, без анимации
INTERVAL="${WALL_CYCLE_INTERVAL:-300}"

mapfile -t WALLS < <(find -L "$WALL_DIR" -type f -name '*.png' | sort)
if [ "${#WALLS[@]}" -eq 0 ]; then
    echo "wall-cycle: no wallpapers in $WALL_DIR" >&2
    exit 1
fi

# Текущие обои по выходам, чтобы не выбирать одну и ту же картинку дважды подряд.
declare -A CURRENT

pick_wall() {
    local output="$1" candidate
    if [ "${#WALLS[@]}" -eq 1 ]; then
        echo "${WALLS[0]}"
        return
    fi
    while :; do
        candidate="${WALLS[RANDOM % ${#WALLS[@]}]}"
        [ "$candidate" != "${CURRENT[$output]:-}" ] && break
    done
    echo "$candidate"
}

set_wall() {
    local output="$1" wall
    wall="$(pick_wall "$output")"
    CURRENT["$output"]="$wall"
    awww img -o "$output" "$wall" "${TRANSITION[@]}"
}

set_all() {
    while IFS= read -r output; do
        [ -n "$output" ] && set_wall "$output"
    done < <(niri msg -j outputs | jq -r 'keys[]')
}

# Ждём, пока awww-daemon поднимет сокет (его запускает niri параллельно с нами).
for _ in $(seq 1 50); do
    awww query >/dev/null 2>&1 && break
    sleep 0.1
done

set_all
while sleep "$INTERVAL"; do
    # Если niri умер, awww тоже недоступен: выходим вместе с сессией.
    awww query >/dev/null 2>&1 || exit 0
    set_all
done
