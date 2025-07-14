#!/bin/bash
CONFIG_FILE="./imon-iscsi.conf"
HOSTNAME=$(hostname)

if ! command -v iscsiadm >/dev/null 2>&1; then
    echo "🔧 'iscsiadm' not found. Installing..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y open-iscsi
    else
        echo "❌ Cannot install 'iscsiadm'. Unsupported system."
        exit 1
    fi
fi

declare -a TARGETS
declare -a MOUNTS
EMAIL=""
MIN_SIZE_TB=2
CHECK_INTERVAL=10

install_service() {
    echo "Installing imon-iscsi systemd service..."
    sudo cp imon-iscsi.sh /usr/local/bin/imon-iscsi.sh
    sudo chmod +x /usr/local/bin/imon-iscsi.sh
    sudo cp imon-iscsi.service /etc/systemd/system/imon-iscsi.service
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable imon-iscsi.service
    sudo systemctl start imon-iscsi.service
    echo "✅ Service installed and started."
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        IFS=';' read -ra TARGETS <<< "$TARGETS_RAW"
        IFS=';' read -ra MOUNTS <<< "$MOUNTS_RAW"
    fi
}

save_config() {
    TARGETS_RAW=$(IFS=';'; echo "${TARGETS[*]}")
    MOUNTS_RAW=$(IFS=';'; echo "${MOUNTS[*]}")
    cat <<EOF > "$CONFIG_FILE"
EMAIL="$EMAIL"
MIN_SIZE_TB=$MIN_SIZE_TB
CHECK_INTERVAL=$CHECK_INTERVAL
TARGETS_RAW="$TARGETS_RAW"
MOUNTS_RAW="$MOUNTS_RAW"
HOSTNAME="$HOSTNAME"
EOF
}

print_targets() {
    echo "Current targets and mount points:"
    for i in "${!TARGETS[@]}"; do
        echo "$((i+1)). TARGET: ${TARGETS[$i]}  →  MOUNT: ${MOUNTS[$i]}"
    done
}

discover_targets() {
    echo "Scanning available iSCSI targets..."
    mapfile -t AVAILABLE_TARGETS < <(iscsiadm -m node | awk '{print $2}' | sort)
    if [[ ${#AVAILABLE_TARGETS[@]} -eq 0 ]]; then
        echo "❌ No iSCSI targets found."
        return 1
    fi
    echo "Available iSCSI Targets:"
    for i in "${!AVAILABLE_TARGETS[@]}"; do
        echo "$((i+1)). ${AVAILABLE_TARGETS[$i]}"
    done
    read -p "Select target number: " selected
    local index=$((selected-1))
    if [[ -z "${AVAILABLE_TARGETS[$index]}" ]]; then
        echo "❌ Invalid selection."
        return 1
    fi
    TARGET="${AVAILABLE_TARGETS[$index]}"
    return 0
}

add_entry() {
    if discover_targets; then
        read -p "Enter mount point for this target: " MOUNT
        TARGETS+=("$TARGET")
        MOUNTS+=("$MOUNT")
        echo "✅ Target added."
    fi
}

remove_entry() {
    print_targets
    read -p "Select entry number to remove: " selected
    local index=$((selected-1))
    if [[ -n "${TARGETS[$index]}" ]]; then
        unset 'TARGETS[index]'
        unset 'MOUNTS[index]'
        TARGETS=("${TARGETS[@]}")
        MOUNTS=("${MOUNTS[@]}")
        echo "✅ Entry removed."
    else
        echo "❌ Invalid selection."
    fi
}

edit_entry() {
    print_targets
    read -p "Select entry number to edit: " selected
    local index=$((selected-1))
    if [[ -z "${TARGETS[$index]}" ]]; then
        echo "❌ Invalid selection."
        return
    fi
    echo "Editing entry ${selected}:"
    echo "1. Change iSCSI target"
    echo "2. Change mount point"
    read -p "Choose option: " opt
    case $opt in
        1)
            if discover_targets; then
                TARGETS[$index]="$TARGET"
                echo "✅ Target updated."
            fi
            ;;
        2)
            read -p "Enter new mount point: " new_mount
            MOUNTS[$index]="$new_mount"
            echo "✅ Mount point updated."
            ;;
        *)
            echo "❌ Invalid option."
            ;;
    esac
}

set_general_options() {
    read -p "Minimum disk size (TB, default: $MIN_SIZE_TB): " input_size
    read -p "Check interval (seconds, default: $CHECK_INTERVAL): " input_interval
    read -p "Alert email (current: $EMAIL): " input_email
    [[ -n "$input_size" ]] && MIN_SIZE_TB="$input_size"
    [[ -n "$input_interval" ]] && CHECK_INTERVAL="$input_interval"
    [[ -n "$input_email" ]] && EMAIL="$input_email"
    echo "✅ General settings updated."
}

load_config
while true; do
    echo ""
    echo "========== iMON-iSCSI Configuration Menu =========="
    echo "1. Add new iSCSI target"
    echo "2. Edit existing entry"
    echo "3. Remove entry"
    echo "4. View current configuration"
    echo "5. Set general options"
    echo "6. Save and exit"
    echo "7. Exit without saving"
    echo "8. Install and enable systemd service"
    read -p "Select an option: " choice
    case $choice in
        1) add_entry ;;
        2) edit_entry ;;
        3) remove_entry ;;
        4) print_targets ;;
        5) set_general_options ;;
        6) save_config; echo "✅ Configuration saved to $CONFIG_FILE."; exit 0 ;;
        7) echo "❌ Exit without saving."; exit 0 ;;
        8) install_service ;;
        *) echo "❌ Invalid option." ;;
    esac
done
