#!/bin/bash
#/usr/local/bin/imon-iscsi.sh

EMAIL="adresa_ta_email@domeniu.com"
LOGFILE="/var/log/imon-iscsi.log"
TARGETS=("iqn.2004-04.com.qnap:ts-451plus:iscsi.target-0.imm-top")
MOUNTS=("/mnt/veeam/")
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
            echo "$(date) - ALERT: $TARGET nu este conectat. Se încearcă reconectare..." | tee -a "$LOGFILE"
            iscsiadm -m node -T "$TARGET" --login
            sleep 3
        fi

        if ! check_mount_valid "$MOUNT"; then
            echo "$(date) - ALERT: $MOUNT inaccesibil sau sub ${MIN_SIZE}GB. Se remontează..." | tee -a "$LOGFILE"
            umount -f "$MOUNT"
            sleep 2
            mount "$MOUNT"

            if ! check_mount_valid "$MOUNT"; then
                echo "$(date) - EROARE: Remount eșuat la $MOUNT" | tee -a "$LOGFILE" | msmtp "$EMAIL"
            else
                echo "$(date) - $MOUNT montat cu succes după reconectare." | tee -a "$LOGFILE"
            fi
        else
            echo "$(date) - OK: $MOUNT este montat corect." >> "$LOGFILE"
        fi
    done
    sleep 10
done
