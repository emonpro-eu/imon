# iMON-iSCSI Monitor ![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

iMON-iSCSI is a bash-based iSCSI monitor and remount daemon for Linux.

The script creates a service that monitors every 10 seconds if the iscsci target is mounted and if not, mounts it. It is useful in iscsi connections over vpn, where there can be disconnections due to various connection problems. The most common is when you do Offsite backups over slow connections. It does not check if there is a connection to the iscsi target, nor does it create one.
This is the first version, I hope there will be others to follow. To send reports by email, you need to install the msmtp package and configure it accordingly.

## Features

- Automatic reconnection to iSCSI targets
- Automatic remounting of missing volumes
- Email alerts via `msmtp`
- Interactive installer with menu for adding, removing, editing targets
- systemd service support

## Quick Start

Install:
git clone https://github.com/emonpro-eu/imon.git
cd imon/
chmod +x install.sh
./install.sh

Uninstall:
chmod +x uninstall.sh
./uninstall.sh

## License

[MIT License](LICENSE)
