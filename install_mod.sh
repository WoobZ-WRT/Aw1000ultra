#!/bin/sh

# ==============================================================================
# AUTO-MOD INSTALLER SCRIPT - TELSTRA 5G (WoobZ-WRT)
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

# ------------------------------------------------------------------------------
# STAGE 1: REPOSITORY UPDATE & DEPENDENCY INSTALLATION
# ------------------------------------------------------------------------------
echo -e "${CYAN}[1/5] Updating repositories and installing system packages...${NC}"

# Redirect EOL OpenWrt 19.07.7 feeds to archive.openwrt.org & disable dead feeds
sed -i 's|downloads.openwrt.org|archive.openwrt.org|g' /etc/opkg/distfeeds.conf
sed -i 's|aarch64_cortex-a55_neon-vfpv4|aarch64_generic|g' /etc/opkg/distfeeds.conf
sed -i '/mt6890/s/^/#/' /etc/opkg/distfeeds.conf
sed -i '/lienol/s/^/#/' /etc/opkg/distfeeds.conf

# Register supported architectures so theme (all/noarch) & system packages are recognized
grep -q "arch all" /etc/opkg.conf || echo "arch all 1" >> /etc/opkg.conf
grep -q "arch noarch" /etc/opkg.conf || echo "arch noarch 1" >> /etc/opkg.conf
grep -q "arch aarch64_generic" /etc/opkg.conf || echo "arch aarch64_generic 10" >> /etc/opkg.conf
grep -q "arch aarch64_cortex-a55_neon-vfpv4" /etc/opkg.conf || echo "arch aarch64_cortex-a55_neon-vfpv4 20" >> /etc/opkg.conf

opkg update

echo -e "${YELLOW}Installing curl & SSL certificates (GitHub anti-timeout)...${NC}"
opkg install curl ca-bundle

echo -e "${YELLOW}Installing luci-theme-material...${NC}"
opkg install luci-theme-material

echo -e "${YELLOW}Installing PHP components for TinyFM...${NC}"
opkg install php7 php7-cgi php7-mod-ctype php7-mod-dom php7-mod-fileinfo \
             php7-mod-iconv php7-mod-json php7-mod-mbstring php7-mod-session

echo -e "${GREEN}Base package installation completed!${NC}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 2: DOWNLOAD, EXTRACT & APPLY MODIFICATION FILES
# ------------------------------------------------------------------------------
echo -e "${CYAN}[2/5] Downloading and applying system modification files...${NC}"
BACKUP_FILE="/tmp/aw1000_ultra_mod.tar.gz"
DOWNLOAD_URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/download/v1.0/aw1000_ultra_mod.tar.gz"

rm -f "$BACKUP_FILE"
echo -e "${YELLOW}Downloading modification package from GitHub server...${NC}"

if command -v curl >/dev/null 2>&1; then
    curl -4 -fL --retry 3 --retry-delay 3 --connect-timeout 15 -k -o "$BACKUP_FILE" "$DOWNLOAD_URL"
else
    wget --no-check-certificate -T 20 -O "$BACKUP_FILE" "$DOWNLOAD_URL"
fi

echo -e "${YELLOW}Extracting and applying directory structure...${NC}"
if ! tar -xzf "$BACKUP_FILE" -C /; then
    echo -e "${RED}ERROR: Failed to download or extract aw1000_ultra_mod.tar.gz!${NC}"
    echo -e "${YELLOW}Please ensure your internet connection is stable and the GitHub Release asset is available.${NC}"
    rm -f "$BACKUP_FILE"
    exit 1
fi

rm -f "$BACKUP_FILE"

# Ensure initial version marker exists
[ ! -f /etc/aw1kv2_version ] && echo "1.0" > /etc/aw1kv2_version

echo -e "${GREEN}Modification files applied successfully!${NC}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 3: INSTALL AUTO-REFRESH IP SCRIPT (cek_wan.sh)
# ------------------------------------------------------------------------------
echo -e "${CYAN}[3/5] Setting up Auto-Refresh IP system (Ping Monitor)...${NC}"

cat << 'EOF' > /root/cek_wan.sh
#!/bin/sh

IFACE_TELSTRA="wan"

if [ -f /tmp/wan_cooldown ]; then
    exit 0
fi

if ping -c 3 -W 3 8.8.8.8 > /dev/null; then
    exit 0
else
    logger "Ping Timeout: No internet. Restarting local WAN interface...."
    echo "$(date): Ping Timeout: No internet. Restarting local WAN interface...." >> /root/log_restart_wan.txt

    tail -n 25 /root/log_restart_wan.txt > /tmp/log_temp.txt
    mv /tmp/log_temp.txt /root/log_restart_wan.txt
    
    touch /tmp/wan_cooldown
    ifdown $IFACE_TELSTRA
    sleep 5
    ifup $IFACE_TELSTRA
    sleep 15
    rm -f /tmp/wan_cooldown
fi
EOF

chmod +x /root/cek_wan.sh
sed -i '/cek_wan.sh/d' /etc/crontabs/root

cat << 'EOF' >> /etc/crontabs/root
* * * * * /root/cek_wan.sh
* * * * * sleep 12; /root/cek_wan.sh
* * * * * sleep 24; /root/cek_wan.sh
* * * * * sleep 36; /root/cek_wan.sh
* * * * * sleep 48; /root/cek_wan.sh
EOF

/etc/init.d/cron restart
echo -e "${GREEN}Auto-Refresh IP system is now active!${NC}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 4: CONFIGURE PERMISSIONS & TINYFM BIND MOUNT
# ------------------------------------------------------------------------------
echo -e "${CYAN}[4/5] Configuring LuCI permissions and mounting TinyFM...${NC}"

chmod -R 755 /www/cgi-bin
chmod -R 755 /www/luci-static

mkdir -p /www/tinyfm/rootfs
grep -q "/www/tinyfm/rootfs" /proc/mounts || mount --rbind / /www/tinyfm/rootfs

grep -q "mount --rbind / /www/tinyfm/rootfs" /etc/rc.local || sed -i '/exit 0/i mount --rbind / /www/tinyfm/rootfs' /etc/rc.local

echo -e "${GREEN}Permissions and TinyFM configured successfully!${NC}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 5: FINISHING & RESTARTING SERVICES
# ------------------------------------------------------------------------------
echo -e "${CYAN}[5/5] Applying all changes and restarting services...${NC}"

rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/
/etc/init.d/uhttpd restart
/etc/init.d/network restart > /dev/null 2>&1

echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}  INSTALLATION COMPLETED SUCCESSFULLY!              ${NC}"
echo -e "${YELLOW}  Please refresh your web browser page.             ${NC}"
echo -e "${CYAN}====================================================${NC}"

rm -f "$0" /tmp/install_mod.sh
exit 0
