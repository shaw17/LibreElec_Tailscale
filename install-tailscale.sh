#!/bin/bash

# This script installs, configures, and updates Tailscale on a LibreELEC system.
# It automatically detects if a new version is available and installs it.
# If an update is performed, it automatically restarts the service to restore remote access.
# It also adds a non-intrusive update check that shows a GUI notification in Kodi.
# It can be run multiple times safely. v9 - remote-safe updates.

# --- Configuration ---
INSTALL_DIR="/storage/tailscale"
AUTORUN_SCRIPT_PATH="/storage/.config/autostart.sh"

# --- Function to display structured, high-contrast output ---
function cecho {
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

cecho header "Tailscale Installer & Updater"

# --- Check if running as root ---
if [ "$(id -u)" -ne 0 ]; then
  cecho error "This script must be run as root."
  exit 1
fi

# --- Update & Installation Phase ---
cecho info "Checking for the latest Tailscale version..."
LATEST_VERSION=$(curl -s https://pkgs.tailscale.com/stable/ | grep -o 'tailscale_[0-9.]*_' | sed 's/tailscale_//;s/_//' | sort -V | tail -n1)
if [ -z "$LATEST_VERSION" ]; then
    cecho error "Could not determine the latest Tailscale version. Check network connection."
    exit 1
fi
cecho ok "Latest version is: ${LATEST_VERSION}"

CURRENT_VERSION=""
if [ -f "${INSTALL_DIR}/tailscaled" ]; then
    CURRENT_VERSION=$(${INSTALL_DIR}/tailscale --version | head -n1)
    cecho info "Current installed version is: ${CURRENT_VERSION}"
fi

if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
    cecho ok "Tailscale is already up-to-date."
else
    if [ -z "$CURRENT_VERSION" ]; then
        cecho info "Tailscale not found. Starting new installation..."
    else
        cecho info "New version available. Updating from ${CURRENT_VERSION}..."
        cecho info "Stopping existing Tailscale services..."
        # Stop the running daemon before replacing the file. Redirect errors to null.
        killall tailscaled >/dev/null 2>&1 || true
        sleep 2
    fi

    # --- Perform Download and Extraction ---
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64) TS_ARCH="amd64" ;; aarch64) TS_ARCH="arm64" ;; armv7l) TS_ARCH="arm" ;;
      *) cecho error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    TGZ_FILE="tailscale_${LATEST_VERSION}_${TS_ARCH}.tgz"
    DOWNLOAD_URL="https://pkgs.tailscale.com/stable/${TGZ_FILE}"
    mkdir -p "${INSTALL_DIR}"; cd "${INSTALL_DIR}"
    cecho info "Downloading version ${LATEST_VERSION}..."
    wget -q -O "${TGZ_FILE}" "${DOWNLOAD_URL}"
    cecho info "Extracting files..."
    tar xvf "${TGZ_FILE}" --strip-components=1
    rm "${TGZ_FILE}"; chmod +x tailscale tailscaled
    cecho ok "Successfully installed/updated to version ${LATEST_VERSION}."

    # --- Restart Service to Restore Remote Access ---
    cecho info "Restarting Tailscale service..."
    # Start the new daemon in the background
    (cd ${INSTALL_DIR} && ./tailscaled --state=${INSTALL_DIR}/tailscaled.state) &
    # Bring the connection up after a short delay
    (sleep 5 && ${INSTALL_DIR}/tailscale up --ssh) &
    cecho ok "Tailscale has been restarted to restore remote access."
fi

# --- Configuration checks remain the same ---
cecho header "STARTUP CONFIG"
mkdir -p /storage/.config
if [ ! -f "$AUTORUN_SCRIPT_PATH" ]; then
    cecho info "Creating new autostart script."
    touch "$AUTORUN_SCRIPT_PATH"; chmod +x "$AUTORUN_SCRIPT_PATH"
    echo "#!/bin/bash" > "$AUTORUN_SCRIPT_PATH"
fi

if grep -q "tailscaled" "$AUTORUN_SCRIPT_PATH"; then cecho ok "Tailscale daemon is configured to start at boot."; else
    cecho info "Adding Tailscale daemon to startup script..."; { echo ""; echo "# Start Tailscale daemon"; echo "(cd ${INSTALL_DIR} && ./tailscaled --state=${INSTALL_DIR}/tailscaled.state) &"; } >> "$AUTORUN_SCRIPT_PATH"; cecho ok "Daemon configured."; fi
if grep -q "tailscale up" "$AUTORUN_SCRIPT_PATH"; then cecho ok "'tailscale up' is configured to run at boot."; else
    cecho info "Adding 'tailscale up --ssh' to startup script..."; { echo ""; echo "# Connect to Tailnet and enable SSH"; echo "(sleep 10 && ${INSTALL_DIR}/tailscale up --ssh) &"; } >> "$AUTORUN_SCRIPT_PATH"; cecho ok "SSH startup command configured."; fi

cecho header "GUI UPDATE CHECK"
if grep -q "# Tailscale Update Check" "$AUTORUN_SCRIPT_PATH"; then cecho ok "GUI update check is already configured."; else
    cecho info "Adding GUI update check to startup script..."; cat << 'EOF' >> "$AUTORUN_SCRIPT_PATH"

# Tailscale Update Check (runs in the background after boot)
(
  sleep 300
  INSTALL_DIR="/storage/tailscale"
  if [ -f "${INSTALL_DIR}/tailscale" ]; then
    CURRENT_VERSION=$(${INSTALL_DIR}/tailscale --version | head -n1); LATEST_VERSION=$(curl -s https://pkgs.tailscale.com/stable/ | grep -o 'tailscale_[0-9.]*_' | sed 's/tailscale_//;s/_//' | sort -V | tail -n1)
    if [ -n "$LATEST_VERSION" ] && [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
      TITLE="Tailscale Update Available"; MESSAGE="New version ${LATEST_VERSION} is available. Re-run the installer script to update."
      curl -s -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"GUI.ShowNotification\",\"params\":{\"title\":\"${TITLE}\",\"message\":\"${MESSAGE}\",\"displaytime\":15000,\"image\":\"info\"},\"id\":1}" http://localhost:8080/jsonrpc >/dev/null
    fi
  fi
) &
EOF
    cecho ok "Update check configured."
fi

# --- Final Instructions ---
cecho header "COMPLETE"
cecho info "All checks and configurations are complete."
cecho info "If an update was performed, the Tailscale service has been restarted."
echo
cecho info "A full reboot is still recommended for a clean state."
cecho info "To restart your device now, run:"
cecho cmd "  reboot"
echo
