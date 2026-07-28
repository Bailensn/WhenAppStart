#!/system/bin/sh

MODDIR=${0%/*}
LOG="$MODDIR/logout.log"
MODULE_TMP="$MODDIR/tmp"
CONFIG_FILE="$MODDIR/handle.conf"

mkdir -p "$MODULE_TMP"
export TMPDIR="$MODULE_TMP"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG"
}

cleanup_tmp() {
    find "$MODULE_TMP" -type f -mmin +60 -delete 2>/dev/null
}

get_main_pid() {
    local pkg="$1"
    local pid=""
    pid=$(pidof "$pkg" 2>/dev/null | awk '{print $1}')
    if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
        if grep -qz "^${pkg}$" "/proc/$pid/cmdline" 2>/dev/null; then
            echo "$pid"
            return
        fi
    fi
    for proc_dir in /proc/[0-9]*; do
        pid=$(basename "$proc_dir")
        if grep -qz "^${pkg}$" "$proc_dir/cmdline" 2>/dev/null; then
            echo "$pid"
            return
        fi
    done
}

handle_game() {
    local name="$1"
    local pkg="$2"
    shift 2
    mkdir -p "$MODDIR/assets/$name"
    PID_FILE="$MODDIR/assets/$name/pid.txt"
    current_pid=$(get_main_pid "$pkg")
    if [ -z "$current_pid" ]; then
        if [ -f "$PID_FILE" ]; then
            rm -f "$PID_FILE"
            log ">>> $name exited, pid.txt cleared"
        fi
        return
    fi
    last_pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ "$current_pid" != "$last_pid" ]; then
        cleanup_tmp
        log ">>> New or changed $name PID: $current_pid (was: $last_pid)"
        for script_entry in "$@"; do
            script_name="${script_entry%%:*}"
            input="${script_entry#*:}"
            if [ "$input" = "$script_entry" ]; then
                input=""
            fi
            script_path="$MODDIR/assets/$name/$script_name"
            if [ ! -f "$script_path" ]; then
                log "Script not found: $script_path"
                continue
            fi
            if [ -n "$input" ]; then
                echo "$input" | sh "$script_path" >>"$LOG" 2>&1
            else
                sh "$script_path" >>"$LOG" 2>&1
            fi
        done
        echo "$current_pid" >"$PID_FILE"
        log ">>> PID updated and scripts executed for $name"
    fi
}

if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
else
    log "ERROR: $CONFIG_FILE not found!"
    exit 1
fi

log "==== Game watcher started ===="

while true; do
    get_games_config | while IFS='|' read -r name pkg scripts; do
        [ -z "$name" ] && continue
        name="${name#"${name%%[! ]*}"}"
        name="${name%"${name##*[! ]}"}"
        pkg="${pkg#"${pkg%%[! ]*}"}"
        pkg="${pkg%"${pkg##*[! ]}"}"
        scripts="${scripts#"${scripts%%[! ]*}"}"
        scripts="${scripts%"${scripts##*[! ]}"}"
        set -- "$name" "$pkg"
        old_ifs="$IFS"
        IFS=', '
        for s in $scripts; do
            [ -n "$s" ] && set -- "$@" "$s"
        done
        IFS="$old_ifs"
        handle_game "$@"
    done
    sleep 5
done
