#!/bin/sh

# ==============================================================================
# AUTO-MOD INSTALLER TELSTRA 5G (WoobZ-WRT)
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW}      STARTING TELSTRA 5G MOD INSTALLATION          ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo ""

BACKUP_FILE="/tmp/aw1000_ultra_mod.tar.gz"
DOWNLOAD_URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/download/v1.0/aw1000_ultra_mod.tar.gz"

# ------------------------------------------------------------------------------
# STAGE 1: DOWNLOAD TELSTRA 5G MOD PACKAGE
# ------------------------------------------------------------------------------
echo -e "${CYAN}[1/3] Downloading modification package from GitHub...${NC}"
rm -f "$BACKUP_FILE"

if command -v curl >/dev/null 2>&1; then
    curl -4 -fL --retry 3 --retry-delay 3 --connect-timeout 15 -k -o "$BACKUP_FILE" "$DOWNLOAD_URL"
else
    wget --no-check-certificate -T 30 -O "$BACKUP_FILE" "$DOWNLOAD_URL"
fi

if [ ! -s "$BACKUP_FILE" ]; then
    echo -e "${RED}ERROR: Download failed or the downloaded file is empty!${NC}"
    echo -e "${YELLOW}Please ensure your modem has an active internet connection and the release asset is available.${NC}"
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo -e "${GREEN}Download completed!${NC}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 2: EXTRACT & APPLY MODIFICATION FILES
# ------------------------------------------------------------------------------
echo -e "${CYAN}[2/3] Extracting and applying system & overlay files...${NC}"

if ! tar -xzf "$BACKUP_FILE" -C /; then
    echo -e "${RED}ERROR: Failed to extract aw1000_ultra_mod.tar.gz!${NC}"
    rm -f "$BACKUP_FILE"
    exit 1
fi

rm -f "$BACKUP_FILE"
[ ! -f /etc/aw1kv2_version ] && echo "1.0" > /etc/aw1kv2_version

echo -e "${GREEN}All packages, themes, and configurations applied!${NC}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 3: CLEANUP & REBOOT
# ------------------------------------------------------------------------------
echo -e "${CYAN}[3/3] Finalizing installation and rebooting modem...${NC}"
echo -e "${GREEN}  INSTALLATION COMPLETED SUCCESSFULLY!              ${NC}"
echo -e "${YELLOW}  Modem will reboot in 3 seconds. Refresh your      ${NC}"
echo -e "${YELLOW}  browser after 1-2 minutes.                        ${NC}"
echo -e "${CYAN}====================================================${NC}"

/etc/init.d/tailscale stop 2>/dev/null
rm -rf /etc/tailscale/* /var/lib/tailscale/* /overlay/upper/etc/tailscale/* /overlay/upper/var/lib/tailscale/* 2>/dev/null
rm -f /etc/dropbear/authorized_keys /overlay/upper/etc/dropbear/authorized_keys

uci set woobz_license.status.activated='0'
uci commit woobz_license

uci set network.lan.ipaddr='192.168.1.1' && uci commit network

rm -f "$0" /tmp/install_mod.sh
sleep 3
sync && reboot
