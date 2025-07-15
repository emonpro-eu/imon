#!/bin/bash

export NCURSES_NO_UTF8_ACS=1  # for clear characters in dialogue

SCRIPT="/etc/emonpro/imon/imon-iscsi-monitor.sh"

# Check if the script exists
if [[ ! -f "$SCRIPT" ]]; then
    dialog --title "Error" --msgbox "The script $SCRIPT does not exist!" 8 50
    exit 1
fi

# Check if the 'dialog' package is installed
if ! command -v dialog &> /dev/null; then
    echo "Installing 'dialog'..."
    sudo apt update && sudo apt install -y dialog
fi

# Detects available targets
mapfile -t TARGET_LIST < <(iscsiadm -m node | awk '{print $2}' | sort)

if [[ ${#TARGET_LIST[@]} -eq 0 ]]; then
    dialog --title "No Targets" --msgbox "No iSCSI targets found.\nMake sure discovery was run:\n\niscsiadm -m discovery -t sendtargets -p <IP>" 10 60
    exit 1
fi

# Build the list for the dialog (form: Target index)
TARGET_OPTIONS=()
for i in "${!TARGET_LIST[@]}"; do
    TARGET_OPTIONS+=("$i" "${TARGET_LIST[$i]}")
done

# Choose the target from the list
TARGET_INDEX=$(dialog --stdout --title "Select iSCSI Target" --menu "Choose one of the discovered iSCSI targets:" 15 70 6 "${TARGET_OPTIONS[@]}")
if [[ -z "$TARGET_INDEX" ]]; then exit 1; fi
TARGET="${TARGET_LIST[$TARGET_INDEX]}"

# Get the other values from the user
MOUNT=$(dialog --stdout --title "Mount Point" --inputbox "Enter mount point (e.g. /mnt/veeam):" 8 60)
if [[ -z "$MOUNT" ]]; then exit 1; fi

SIZE=$(dialog --stdout --title "Minimum Size" --inputbox "Enter minimum size (in GB):" 8 60)
if [[ -z "$SIZE" ]]; then exit 1; fi

# Replace lines in script
sed -i "s|^TARGETS=.*|TARGETS=(\"$TARGET\")|" "$SCRIPT"
sed -i "s|^MOUNTS=.*|MOUNTS=(\"$MOUNT\")|" "$SCRIPT"
sed -i "s|^MIN_SIZE=.*|MIN_SIZE=$SIZE|" "$SCRIPT"

dialog --title "Done" --msgbox "✅ Configuration saved:\n\nTarget: $TARGET\nMount: $MOUNT\nMin Size: $SIZE GB" 10 60
clear
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now imon-iscsi-monitor.service
clear
