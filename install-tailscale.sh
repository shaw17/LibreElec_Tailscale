#!/bin/bash

# This script installs and configures Tailscale on a LibreELEC system.
# It checks for existing installations and ensures the SSH server is enabled at boot.
# It can be run multiple times safely. v6 - enhanced readability layout.

# --- Configuration ---
INSTALL_DIR="/storage/tailscale"
AUTORUN_SCRIPT_PATH="/storage/.config/autostart.sh"

# --- Function to display structured, high-contrast output ---
function cecho {
    # High-contrast, structured color scheme.
    local BOLD="\033[1m"
    local GREEN="\033[1;32m"
    local YELLOW="\033[1;33m"
    local RED="\033[1;31m"
    local NC="\033[0m"

    case "$1" in
        header)
            printf "\n%b--- %s ---%b\n" "${BOLD}" "$2" "${NC}"
            ;;
        ok)
            printf "  %b✔ OK:%b %s\n" "${GREEN}" "${NC}" "$2"
            ;;
        info)
            printf "  %s\n" "$2"
            ;;
        cmd)
            printf "  %b%s%b\n" "${YELLOW}" "$2" "${NC}"
            ;;
        error)
            printf "\n%bERROR:%b %s\n" "${RED}" "${NC}" "$2"
            ;;
        *)
            echo "$2"
            ;;
    esac
}

cecho header "Tailscale Installer & Configurator"

# --- Check if running as root ---
if [ "$(id -u)" -ne 0 ]; then
  cecho error "This script must be run as root."
  exit 1
fi

# --- Installation Phase ---
cecho header "STATUS"
if [ -f "${INSTALL_DIR}/tailscaled" ]; then
    cecho ok "Tailscale is already installed."
    INSTALLED_VERSION=$(${INSTALL_DIR}/tailscale --version | head -n1)
    cecho info "Version: ${INSTALLED_VERSION}"
else
    cecho info "Tailscale not found. Starting new installation..."

    # Determine Architecture
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64) TS_ARCH="amd64" ;;
      aarch64) TS_ARCH="arm64" ;;
      armv7l) TS_ARCH="arm" ;;
      *)
        cecho error "Unsupported architecture: $ARCH"
        exit 1
        ;;
    esac
    cecho info "Architecture: ${TS_ARCH}"

    # Fetch the latest stable version number
    cecho info "Finding latest version..."
    LATEST_VERSION=$(curl -s https://pkgs.tailscale.com/stable/ | grep -o 'tailscale_[0-9.]*_' | sed 's/tailscale_//;s/_//' | sort -V | tail -n1)

    if [ -z "$LATEST_VERSION" ]; then
        cecho error "Could not determine the latest Tailscale version."
        exit 1
    fi
    cecho ok "Latest version found: $LATEST_VERSION"

    # Download and extract
    TGZ_FILE="tailscale_${LATEST_VERSION}_${TS_ARCH}.tgz"
    DOWNLOAD_URL="https://pkgs.tailscale.com/stable/${TGZ_FILE}"
    mkdir -p "${INSTALL_DIR}"
    cd "${INSTALL_DIR}"
    cecho info "Downloading..."
    wget -q -O "${TGZ_FILE}" "${DOWNLOAD_URL}"
    cecho info "Extracting..."
    tar xvf "${TGZ_FILE}" --strip-components=1
    rm "${TGZ_FILE}"
    chmod +x tailscale tailscaled
    cecho ok "Installation complete."
fi

# --- Configuration Phase ---
cecho header "STARTUP CONFIG"
mkdir -p /storage/.config
if [ ! -f "$AUTORUN_SCRIPT_PATH" ]; then
    cecho info "Creating new autostart script."
    touch "$AUTORUN_SCRIPT_PATH"
    chmod +x "$AUTORUN_SCRIPT_PATH"
    echo "#!/bin/bash" > "$AUTORUN_SCRIPT_PATH"
fi

# Check for Tailscale daemon
if grep -q "tailscaled" "$AUTORUN_SCRIPT_PATH"; then
    cecho ok "Tailscale daemon is configured to start at boot."
else
    cecho info "Adding Tailscale daemon to startup script..."
    { echo ""; echo "# Start Tailscale daemon"; echo "(cd ${INSTALL_DIR} && ./tailscaled --state=${INSTALL_DIR}/tailscaled.state) &"; } >> "$AUTORUN_SCRIPT_PATH"
    cecho ok "Daemon configured."
fi

# Check for 'tailscale up --ssh'
if grep -q "tailscale up" "$AUTORUN_SCRIPT_PATH"; then
    cecho ok "'tailscale up' is configured to run at boot."
else
    cecho info "Adding 'tailscale up --ssh' to startup script..."
    { echo ""; echo "# Connect to Tailnet and enable SSH"; echo "(sleep 10 && ${INSTALL_DIR}/tailscale up --ssh) &"; } >> "$AUTORUN_SCRIPT_PATH"
    cecho ok "SSH startup command configured."
fi

# --- Final Instructions ---
cecho header "ACTION REQUIRED"
cecho info "If this is a new installation, you must log in to Tailscale."
cecho info "To log in and connect this device, run the following command:"
cecho cmd "  /storage/tailscale/tailscale up --ssh"
echo
cecho info "After logging in, or if the device was already configured,"
cecho info "reboot to ensure all services start correctly:"
cecho cmd "  reboot"
echo
