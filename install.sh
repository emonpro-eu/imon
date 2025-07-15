#!/bin/bash

export NCURSES_NO_UTF8_ACS=1

INSTALL_DIR="/etc/emonpro/imon"
SERVICE_FILE="imon-iscsi-monitor.service"
MONITOR_SCRIPT="imon-iscsi-monitor.sh"
GUI_CONFIG_SCRIPT="imon-gui-config.sh"

# Make sure the dialog package is installed
if ! command -v dialog &> /dev/null; then
    echo "Installing 'dialog'..."
    sudo apt update && sudo apt install -y dialog
fi

# 1. Create the installation directory
sudo mkdir -p "$INSTALL_DIR"

# 2. Copy and set permissions for monitor script
if [[ -f "$MONITOR_SCRIPT" ]]; then
    sudo cp "$MONITOR_SCRIPT" "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/$MONITOR_SCRIPT"
else
    dialog --title "Error" --msgbox "File $MONITOR_SCRIPT not found in current directory!" 8 50
    exit 1
fi

# 3. Copy and set permissions for GUI config script
if [[ -f "$GUI_CONFIG_SCRIPT" ]]; then
    sudo cp "$GUI_CONFIG_SCRIPT" "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/$GUI_CONFIG_SCRIPT"
else
    dialog --title "Error" --msgbox "File $GUI_CONFIG_SCRIPT not found in current directory!" 8 50
    exit 1
fi

# Set strict folder and file permissions
sudo chown root:root "$INSTALL_DIR"/*
sudo chmod 750 "$INSTALL_DIR"/*

# 4. Copy the service
if [[ -f "$SERVICE_FILE" ]]; then
    sudo cp "$SERVICE_FILE" /etc/systemd/system/
else
    dialog --title "Error" --msgbox "Service file $SERVICE_FILE not found!" 8 50
    exit 1
fi

# 5. Run the graphical configurator
sudo bash "$INSTALL_DIR/$GUI_CONFIG_SCRIPT"

# 6. Activate and start the service
sudo systemctl daemon-reload
sudo systemctl enable imon-iscsi-monitor.service
sudo systemctl restart imon-iscsi-monitor.service

# 7. Show service status
SERVICE_STATUS=$(systemctl is-active imon-iscsi-monitor.service)
sleep 5
dialog --title "Service Status" --msgbox "imon-iscsi-monitor.service is: $SERVICE_STATUS" 8 40
clear
