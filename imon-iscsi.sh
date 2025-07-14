#!/bin/bash
CONFIG_FILE="./imon-iscsi.conf"
LOGFILE="/var/log/imon-iscsi.log"

source "$CONFIG_FILE"
IFS=';' read -ra TARGETS <<< "$TARGETS_RAW"
IFS=';' read -ra MOUNTS <<< "$MOUNTS_RAW"
HOSTNAME=${HOSTNAME:-$(hostname)}

check_target() {
    iscsiadm -m session | grep -q "$1"
}

check_mount_valid() {
    local mount_point=$1
    if ! ls "$mount_point" >/dev/null 2>&1; then return 1; fi
    local size_bytes=$(df --output=size "$mount_point" | tail -1)
    local size_tb=$(echo "scale=2; $size_bytes / (1024*1024*1024)" | bc)
    local size_tb_int=$(printf "%.0f" "$size_tb")
    [[ "$size_tb_int" -ge "$MIN_SIZE_TB" ]]
}

while true; do
    for i in "${!TARGETS[@]}"; do
        TARGET="${TARGETS[$i]}"
        MOUNT="${MOUNTS[$i]}"
        if ! check_target "$TARGET"; then
            echo "$(date) - [$HOSTNAME] ALERT: $TARGET is not connected. Reconnecting..." | tee -a "$LOGFILE" | msmtp "$EMAIL"
            iscsiadm -m node -T "$TARGET" --login
            sleep 3
        fi

        if ! check_mount_valid "$MOUNT"; then
            echo "$(date) - [$HOSTNAME] ALERT: $MOUNT is inaccessible or too small. Remounting..." | tee -a "$LOGFILE"
            umount -f "$MOUNT"
            sleep 2
            mount "$MOUNT"
            if ! check_mount_valid "$MOUNT"; then
                echo "$(date) - [$HOSTNAME] ERROR: Remount failed for $MOUNT" | tee -a "$LOGFILE" | msmtp "$EMAIL"
            else
                echo "$(date) - [$HOSTNAME] SUCCESS: $MOUNT remounted." | tee -a "$LOGFILE"
            fi
        else
            echo "$(date) - OK: $MOUNT is mounted." >> "$LOGFILE"
        fi
    done
    sleep "$CHECK_INTERVAL"
done
