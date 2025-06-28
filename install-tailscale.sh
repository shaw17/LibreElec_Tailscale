#!/bin/bash

# This script installs and configures Tailscale on a LibreELEC system.
# It checks for existing installations and ensures the SSH server is enabled at boot.
# It can be run multiple times safely.

# Stop on any error
set -e

# --- Configuration ---
INSTALL_DIR="/storage/tailscale"
AUTORUN_SCRIPT_PATH="/storage/.config/autostart.sh"

# --- Function to display colored output ---
function cecho {
    RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m";
    BLUE="\033[0;34m"; BOLD="\033[1m"; NC="\033[0m";
    COLOR_NAME=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    printf "%b%s%b\n" "${!COLOR_NAME}" "$2" "${NC}"
}

cecho bold "--- Tailscale Installer & Configurator for LibreELEC ---"

# --- Check if running as root ---
if [ "$(id -u)" -ne 0 ]; then
  cecho red "Error: This script must be run as root."
  exit 1
fi

# --- Installation Phase ---
if [ -f "${INSTALL_DIR}/tailscaled" ]; then
    cecho green "Tailscale is already installed. Skipping installation."
    INSTALLED_VERSION=$(${INSTALL_DIR}/tailscale --version)
    cecho blue "Installed version: ${INSTALLED_VERSION}"
else
    cecho bold "Starting new Tailscale installation..."

    # Determine Architecture
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64) TS_ARCH="amd64" ;;
      aarch64) TS_ARCH="arm64" ;;
      armv7l) TS_ARCH="arm" ;;
      *)
        cecho red "Unsupported architecture: $ARCH"
        exit 1
        ;;
    esac
    cecho blue "Detected architecture: $ARCH (Tailscale architecture: $TS_ARCH)"

    # Fetch the latest stable version number
    cecho blue "Finding the latest stable Tailscale version..."
    LATEST_VERSION=$(curl -s https://pkgs.tailscale.com/stable/ | grep -o 'tailscale_[0-9.]*_' | sed 's/tailscale_//;s/_//' | sort -V | tail -n1)

    if [ -z "$LATEST_VERSION" ]; then
        cecho red "Could not determine the latest Tailscale version. Exiting."
        exit 1
    fi
    cecho green "Latest stable version found: $LATEST_VERSION"

    # Define file and directory names
    TGZ_FILE="tailscale_${LATEST_VERSION}_${TS_ARCH}.tgz"
    DOWNLOAD_URL="https://pkgs.tailscale.com/stable/${TGZ_FILE}"

    # Download and extract
    mkdir -p "${INSTALL_DIR}"
    cd "${INSTALL_DIR}"
    cecho blue "Downloading Tailscale v${LATEST_VERSION}..."
    wget -q -O "${TGZ_FILE}" "${DOWNLOAD_URL}"
    cecho blue "Extracting..."
    tar xvf "${TGZ_FILE}" --strip-components=1
    rm "${TGZ_FILE}"
    chmod +x tailscale tailscaled
    cecho green "Installation complete."
fi

# --- Configuration Phase ---
cecho bold "\nVerifying startup configuration..."

# Create autostart directory and script if they don't exist
mkdir -p /storage/.config
if [ ! -f "$AUTORUN_SCRIPT_PATH" ]; then
    cecho yellow "Creating new autostart script at ${AUTORUN_SCRIPT_PATH}"
    touch "$AUTORUN_SCRIPT_PATH"
    chmod +x "$AUTORUN_SCRIPT_PATH"
    echo "#!/bin/bash" > "$AUTORUN_SCRIPT_PATH"
fi

# Check for and add the Tailscale daemon to autostart
if grep -q "tailscaled" "$AUTORUN_SCRIPT_PATH"; then
    cecho green "OK: Tailscale daemon is already configured to start at boot."
else
    cecho yellow "Adding Tailscale daemon to startup script..."
    {
        echo ""
        echo "# Start Tailscale daemon in the background"
        echo "(cd ${INSTALL_DIR} && ./tailscaled --state=${INSTALL_DIR}/tailscaled.state) &"
    } >> "$AUTORUN_SCRIPT_PATH"
    cecho green "Daemon configured."
fi

# Check for and add 'tailscale up --ssh' to autostart
if grep -q "tailscale up" "$AUTORUN_SCRIPT_PATH"; then
    cecho green "OK: 'tailscale up' command is already configured to run at boot."
else
    cecho yellow "Adding 'tailscale up --ssh' to startup script..."
    {
        echo ""
        echo "# Connect to Tailnet and enable SSH, after a short delay"
        echo "(sleep 10 && ${INSTALL_DIR}/tailscale up --ssh) &"
    } >> "$AUTORUN_SCRIPT_PATH"
    cecho green "SSH startup command configured."
fi

# --- Final Instructions ---
cecho bold "\n--- Configuration Verified ---"
echo
cecho bold "NEXT STEPS:"
echo "1. If this is a new installation, you must run 'tailscale up' manually once to log in."
echo "   If the device is already on your Tailnet, a reboot is all you need."
echo
cecho bold "   To log in for the first time, run this command:"
cecho yellow "   ${INSTALL_DIR}/tailscale up --ssh"
echo
echo "   This will give you a URL to authenticate the device."
echo
echo "2. After authenticating, a reboot will ensure the full startup process works correctly."
cecho bold "   To reboot now, type:"
cecho yellow "   reboot"
echo
echo "3. You can then connect to this device from any other machine on your Tailnet by running:"
cecho yellow "   ssh root@<LibreELEC-Tailscale-IP-or-Name>"
