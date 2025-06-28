Tailscale Installer for LibreELEC
This script provides a simple, robust way to install, manage, and update Tailscale on any LibreELEC device (including Raspberry Pi and x86-64 systems).

It is designed to be run directly from GitHub and can be used for initial installation and all subsequent updates.

Features
Automated Installation: Installs the correct Tailscale binaries for your device's architecture.

Automatic Updates: When re-run, the script automatically detects if a new version of Tailscale is available, downloads it, and safely performs the update.

Remote-Safe Updates: If you run the script over a Tailscale SSH session, it automatically restarts the service after an update to ensure your remote connection is not permanently lost.

GUI Update Notifications: The script configures a background service that checks for new Tailscale versions each time LibreELEC boots. If an update is found, it displays a non-intrusive notification in the Kodi interface.

Persistent Configuration: Sets up Tailscale to launch automatically on boot, including enabling the Tailscale SSH server for secure remote access.

Idempotent: You can run the script multiple times without causing issues. It will only perform actions if they are needed.

Usage
To install or update Tailscale, SSH into your LibreELEC machine as root and run the following command:

curl -sL https://raw.githubusercontent.com/shaw17/LibreElec_Tailscale/main/install-tailscale.sh | bash
