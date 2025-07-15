#!/bin/bash

export NCURSES_NO_UTF8_ACS=1

INSTALL_DIR="/etc/emonpro/imon"
SERVICE_NAME="imon-iscsi-monitor.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Ensure dialog is available
if ! command -v dialog &> /dev/null; then
    echo "Installing 'dialog'..."
    sudo apt update && sudo apt install -y dialog
fi

# Confirm uninstallation
dialog --title "Uninstall iMON" --yesno "Do you really want to uninstall iMON iSCSI Monitor and remove all its files and services?" 8 60
if [[ $? -ne 0 ]]; then
    dialog --title "Cancelled" --msgbox "Uninstallation cancelled. No changes made." 6 50
    clear
    exit 0
fi

# Stop and disable service
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null
sudo systemctl disable "$SERVICE_NAME" 2>/dev/null

# Remove service file
if [[ -f "$SERVICE_PATH" ]]; then
    sudo rm "$SERVICE_PATH"
fi

# Remove installed files
if [[ -d "$INSTALL_DIR" ]]; then
    sudo rm -rf "$INSTALL_DIR"
fi

# Reload systemd
sudo systemctl daemon-reload

# Show result
dialog --title "Uninstall Complete" --msgbox "✅ iMON iSCSI Monitor has been successfully uninstalled." 7 50
clear

