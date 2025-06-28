#!/bin/bash

# This script installs and configures Tailscale on a LibreELEC system.
# It automates the process of downloading the static binaries,
# setting up the daemon to run on startup, and provides instructions
# for the user to log in.

# Stop on any error
set -e

# Function to display colored output
#   $1: color (red, green, yellow, blue, bold)
#   $2: message
function cecho {
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    BLUE="\033[0;34m"
    BOLD="\033[1m"
    NC="\033[0m" # No Color

    case "$1" in
        red)
            printf "${RED}${2}${NC}\n"
            ;;
        green)
            printf "${GREEN}${2}${NC}\n"
            ;;
        yellow)
            printf "${YELLOW}${2}${NC}\n"
            ;;
        blue)
            printf "${BLUE}${2}${NC}\n"
            ;;
        bold)
            printf "${BOLD}${2}${NC}\n"
            ;;
        *)
            echo "$2"
            ;;
    esac
}

cecho bold "--- Starting Tailscale Installer for LibreELEC ---"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  cecho red "Error: This script must be run as root."
  exit 1
fi

# Determine Architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    TS_ARCH="amd64"
    ;;
  aarch64)
    TS_ARCH="arm64"
    ;;
  armv7l)
    TS_ARCH="arm"
    ;;
  *)
    cecho red "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

cecho blue "Detected architecture: $ARCH (Tailscale architecture: $TS_ARCH)"

# Fetch the latest stable version number
cecho blue "Finding the latest stable Tailscale version..."
# The URL in the original post is for the human-readable page.
# We'll parse the pkgs.tailscale.com/stable/ listing to find the latest version.
# This is a more robust way to get the latest version.
LATEST_VERSION=$(curl -s https://pkgs.tailscale.com/stable/ | grep -o 'tailscale_[0-9.]*_' | sed 's/tailscale_//;s/_//' | sort -V | tail -n1)

if [ -z "$LATEST_VERSION" ]; then
    cecho red "Could not determine the latest Tailscale version. Exiting."
    exit 1
fi

cecho green "Latest stable version found: $LATEST_VERSION"

# Define file and directory names
TS_VERSION_ARCH="tailscale_${LATEST_VERSION}_${TS_ARCH}"
TGZ_FILE="${TS_VERSION_ARCH}.tgz"
DOWNLOAD_URL="https://pkgs.tailscale.com/stable/${TGZ_FILE}"
INSTALL_DIR="/storage/tailscale"

# Create installation directory
cecho blue "Creating installation directory at ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# Download the binary
cecho blue "Downloading Tailscale binary from ${DOWNLOAD_URL}..."
wget -q --show-progress -O "${TGZ_FILE}" "${DOWNLOAD_URL}"

# Extract the binary
cecho blue "Extracting ${TGZ_FILE}..."
# The tarball contains a single directory, e.g., "tailscale_1.28.0_amd64".
# We use --strip-components=1 to pull the contents out of that directory
# and place them directly into our $INSTALL_DIR.
tar xvf "${TGZ_FILE}" --strip-components=1
rm "${TGZ_FILE}"
cecho green "Extraction complete."

# Make binaries executable (should be already, but good practice)
chmod +x tailscale tailscaled

# Create autostart.sh script
AUTORUN_SCRIPT_PATH="/storage/.config/autostart.sh"
cecho blue "Configuring Tailscale to run on startup using ${AUTORUN_SCRIPT_PATH}..."

# Create the .config directory if it doesn't exist
mkdir -p /storage/.config

# Create the autostart script if it doesn't exist
if [ ! -f "$AUTORUN_SCRIPT_PATH" ]; then
    touch "$AUTORUN_SCRIPT_PATH"
    chmod +x "$AUTORUN_SCRIPT_PATH"
    echo "#!/bin/bash" > "$AUTORUN_SCRIPT_PATH"
fi

# Check if Tailscale is already in the autostart script
if grep -q "tailscaled" "$AUTORUN_SCRIPT_PATH"; then
    cecho yellow "Tailscale daemon already appears to be configured in autostart.sh. Skipping."
else
    # Add the command to autostart.sh
    # We run it in a subshell and background it
    {
        echo ""
        echo "# Start Tailscale daemon"
        echo "(cd ${INSTALL_DIR} && ./tailscaled --state=${INSTALL_DIR}/tailscaled.state) &"
    } >> "$AUTORUN_SCRIPT_PATH"
    cecho green "Added Tailscale daemon to autostart.sh"
fi

cecho bold "--- Installation and Configuration Complete! ---"
echo ""
cecho bold "NEXT STEPS:"
echo "1. The Tailscale daemon needs to be started manually for the first time."
echo "   Or, you can just reboot the system."
echo ""
cecho bold "   To start it now, run this command:"
cecho yellow "   (cd ${INSTALL_DIR} && ./tailscaled --state=${INSTALL_DIR}/tailscaled.state) &"
echo ""
cecho bold "2. Once the daemon is running, you need to log in to your Tailnet."
cecho bold "   Run the following command:"
cecho yellow "   ${INSTALL_DIR}/tailscale up"
echo ""
echo "   This will generate a login URL. Copy and paste this URL into a browser"
echo "   on another device to authenticate and add this LibreELEC machine to your Tailnet."
echo ""
cecho bold "3. To check the status of Tailscale at any time, run:"
cecho yellow "   ${INSTALL_DIR}/tailscale status"
echo ""
cecho green "Enjoy using Tailscale on LibreELEC!"
