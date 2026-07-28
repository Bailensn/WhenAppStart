#!/system/bin/sh

MODDIR=${0%/*}
BUSYBOX="/data/adb/ksu/bin/busybox"
DEST="/data/local/tmp"
ARCHIVE_NAME="WAS_Backup.tar.gz"
ARCHIVE_PATH="$DEST/$ARCHIVE_NAME"

wait_key() {
    deadline=$(( $(date +%s) + 10 ))
    while [ "$(date +%s)" -lt "$deadline" ]; do
        events=$(/system/bin/timeout 1 /system/bin/getevent -l 2>/dev/null)
        case "$events" in
            *KEY_VOLUMEUP*)   return 0 ;;
            *KEY_VOLUMEDOWN*) return 1 ;;
        esac
    done
    return 2
}

do_backup() {
    cd "$MODDIR" || exit 1
    find . -not -path '.' \
        -not -name 'action.sh' \
        -not -name 'module.prop' \
        -not -name 'service.sh' \
        | while read -r f; do
        full="$MODDIR/$f"
        [ ! -e "$full" ] && continue
        uid=$($BUSYBOX stat -c '%u' "$full" 2>/dev/null)
        gid=$($BUSYBOX stat -c '%g' "$full" 2>/dev/null)
        mode=$($BUSYBOX stat -c '%a' "$full" 2>/dev/null)
        echo "${uid}:${gid}|${mode}" > "${full}.ownandper"
    done
    $BUSYBOX tar \
        --exclude="action.sh" \
        --exclude="module.prop" \
        --exclude="service.sh" \
        -czf "$ARCHIVE_NAME" .
    find . -name '*.ownandper' -delete
    $BUSYBOX mv "$ARCHIVE_NAME" "$DEST/"
    echo "  ✅ Backup complete: $ARCHIVE_PATH"
}

do_restore() {
    if [ ! -f "$ARCHIVE_PATH" ]; then
        echo "  ❌ Archive not found: $ARCHIVE_PATH"
        return
    fi
    echo "  Extracting..."
    $BUSYBOX tar -xzf "$ARCHIVE_PATH" -C "$MODDIR"
    echo "  Applying ownership & permissions..."
    find "$MODDIR" -name '*.ownandper' | while read -r per_file; do
        target="${per_file%.ownandper}"
        [ ! -e "$target" ] && continue
        IFS='|' read -r owner mode < "$per_file"
        $BUSYBOX chown "$owner" "$target" 2>/dev/null
        $BUSYBOX chmod "$mode" "$target" 2>/dev/null
    done
    find "$MODDIR" -name '*.ownandper' -delete
    $BUSYBOX rm -f "$ARCHIVE_PATH"
    echo " "
    echo "  ✅ Restore complete. Archive deleted."
}


echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📦 Module Data Manager"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " "
echo "  Make your choice:"
echo "  🔊  Volume Up   = Backup"
echo "  🔉  Volume Down = Restore"
echo "  (10 seconds timeout)"
echo " "

wait_key
first_key=$?

case $first_key in
    0)
        echo " "
        echo "  Selected: BACKUP"
        echo "  🔊 Press Volume Up again to CONFIRM"
        echo "  🔉 Press Volume Down to CANCEL"
        echo " "
        wait_key
        second_key=$?
        if [ "$second_key" -eq 0 ]; then
            do_backup
        else
            echo "  ❌ Cancelled"
        fi
        ;;
    1)
        echo " "
        echo "  Selected: RESTORE"
        echo "  🔉 Press Volume Down again to CONFIRM"
        echo "  🔊 Press Volume Up to CANCEL"
        echo " "
        wait_key
        second_key=$?
        if [ "$second_key" -eq 1 ]; then
            do_restore
        else
            echo "  ❌ Cancelled"
        fi
        ;;
    *)
        echo " "
        echo "  ❌ Timeout. Exited."
        ;;
esac
