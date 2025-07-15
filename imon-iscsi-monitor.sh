#!/bin/bash
#/usr/local/bin/imon-iscsi.sh

EMAIL="email@domain.com"
LOGFILE="/var/log/imon-iscsi-monitor.log"
TARGETS=("iqn.TARGET")
MOUNTS=("/mnt/{mount point}/")
MIN_SIZE=900

check_target() {
    local target=$1
    iscsiadm -m session | grep -q "$target"
    return $?
}

check_mount_valid() {
    local mount_point=$1
    if ! ls "$mount_point" >/dev/null 2>&1; then
        return 1
    fi
    size_bytes=$(df --output=size "$mount_point" | tail -1)
    size=$(echo "scale=2; $size_bytes / (1024*1024)" | bc)
    size_int=$(printf "%.0f" "$size")
    [[ "$size_int" -ge "$MIN_SIZE" ]]
    return $?
}

while true; do
    for i in "${!TARGETS[@]}"; do
        TARGET="${TARGETS[$i]}"
        MOUNT="${MOUNTS[$i]}"

        if ! check_target "$TARGET"; then
            echo "$(date) - ALERT: $TARGET is not connected. Trying to reconnect..." | tee -a "$LOGFILE"
            iscsiadm -m node -T "$TARGET" --login
            sleep 3
        fi

        if ! check_mount_valid "$MOUNT"; then
            echo "$(date) - ALERT: $MOUNT inaccessible or under ${MIN_SIZE}GB. Reconnecting..." | tee -a "$LOGFILE"
            umount -f "$MOUNT"
            sleep 2
            mount "$MOUNT"

            if ! check_mount_valid "$MOUNT"; then
                echo "$(date) - ERROR: Reconnection failed at $MOUNT" | tee -a "$LOGFILE" | msmtp "$EMAIL"
            else
                echo "$(date) - $MOUNT mounted successfully after reconnecting." | tee -a "$LOGFILE"
            fi
        else
            echo "$(date) - OK: $MOUNT is mounted correctly." >> "$LOGFILE"
        fi
    done
    sleep 10
done
