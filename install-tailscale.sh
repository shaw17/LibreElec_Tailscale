#!/bin/bash

# This script installs and configures Tailscale on a LibreELEC system.
# It checks for existing installations and ensures the SSH server is enabled at boot.
# It can be run multiple times safely. v5 - high-contrast color scheme.

# --- Configuration ---
INSTALL_DIR="/storage/tailscale"
AUTORUN_SCRIPT_PATH="/storage/.config/autostart.sh"

# --- Function to display colored output (High-Contrast) ---
function cecho {
    # Using a bold, bright color scheme for maximum readability.
    local color_code=""
    case "$1" in
        # Bold Bright Green for success
        green)  color_code="\033[1;92m" ;;
        # Bold Bright Red for errors
        red)    color_code="\033[1;91m" ;;
        # Bold Bright Cyan for informational messages
        info)   color_code="\033[1;96m" ;;
        # Bold Bright Magenta for commands or highlights
        cmd)    color_code="\033[1;95m" ;;
        # Standard Bold for titles
        title)  color_code="\033[1m" ;;
        *)
            echo "$2"
            return
            ;;
    esac
    local NC="\033[0m" # No Color
    printf "%b%s%b\n" "${color_code}" "$2" "${NC}"
}

cecho title "--- Tailscale Installer & Configurator for LibreELEC ---"

# --- Check if running as root ---
if [ "$(id -u)" -ne 0 ]; then
  cecho red "Error: This script must be run as root."
  exit 1
fi

# --- Installation Phase ---
if [ -f "${INSTALL_DIR}/tailscaled" ]; then
    cecho green "Tailscale is already installed. Skipping installation."
    INSTALLED_VERSION=$(${INSTALL_DIR}/tailscale --version)
    cecho info "Installed version: ${INSTALLED_VERSION}"
else
    cecho title "Starting new Tailscale installation..."

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
    cecho info "Detected architecture: $ARCH (Tailscale architecture: $TS_ARCH)"

    # Fetch the latest stable version number
    cecho info "Finding the latest stable Tailscale version..."
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
    cecho info "Downloading Tailscale v${LATEST_VERSION}..."
    wget -q -O "${TGZ_FILE}" "${DOWNLOAD_URL}"
    cecho info "Extracting..."
    tar xvf "${TGZ_FILE}" --strip-components=1
    rm "${TGZ_FILE}"
    chmod +x tailscale tailscaled
    cecho green "Installation complete."
fi

# --- Configuration Phase ---
cecho title "\nVerifying startup configuration..."

# Create autostart directory and script if they don't exist
mkdir -p /storage/.config
if [ ! -f "$AUTORUN_SCRIPT_PATH" ]; then
    cecho cmd "Creating new autostart script at ${AUTORUN_SCRIPT_PATH}"
    touch "$AUTORUN_SCRIPT_PATH"
    chmod +x "$AUTORUN_SCRIPT_PATH"
    echo "#!/bin/bash" > "$AUTORUN_SCRIPT_PATH"
fi

# Check for and add the Tailscale daemon to autostart
if grep -q "tailscaled" "$AUTORUN_SCRIPT_PATH"; then
    cecho green "OK: Tailscale daemon is already configured to start at boot."
else
    cecho cmd "Adding Tailscale daemon to startup script..."
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
    cecho cmd "Adding 'tailscale up --ssh' to startup script..."
    {
        echo ""
        echo "# Connect to Tailnet and enable SSH, after a short delay"
        echo "(sleep 10 && ${INSTALL_DIR}/tailscale up --ssh) &"
    } >> "$AUTORUN_SCRIPT_PATH"
    cecho green "SSH startup command configured."
fi

# --- Final Instructions ---
cecho title "\n--- Configuration Verified ---"
echo
cecho title "NEXT STEPS:"
echo "1. If this is a new installation, you must run 'tailscale up' manually once to log in."
echo "   If the device is already on your Tailnet, a reboot is all you need."
echo
cecho title "   To log in for the first time, run this command:"
cecho cmd "   ${INSTALL_DIR}/tailscale up --ssh"
echo
echo "   This will give you a URL to authenticate the device."
echo
echo "2. After authenticating, a reboot will ensure the full startup process works correctly."
cecho title "   To reboot now, type:"
cecho cmd "   reboot"
echo
echo "3. You can then connect to this device from any other machine on your Tailnet by running:"
cecho cmd "   ssh root@<LibreELEC-Tailscale-IP-or-Name>"
