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
STAGE_DIR="/tmp/mod_stage"
DOWNLOAD_URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/download/v1.0/aw1000_ultra_mod.tar.gz"

# ------------------------------------------------------------------------------
# STAGE 1: DOWNLOAD TELSTRA 5G MOD PACKAGE
# ------------------------------------------------------------------------------
echo -e "${CYAN}[1/3] Downloading modification package from GitHub...${NC}"
rm -f "$BACKUP_FILE"
rm -rf "$STAGE_DIR"

if command -v curl >/dev/null 2>&1; then
    curl -4 -fL --retry 3 --retry-delay 3 --connect-timeout 15 -k -o "$BACKUP_FILE" "$DOWNLOAD_URL"
else
    wget --no-check-certificate -T 30 -O "$BACKUP_FILE" "$DOWNLOAD_URL"
fi

if [ ! -s "$BACKUP_FILE" ]; then
    echo -e "${RED}ERROR: Download failed or the downloaded file is empty!${NC}"
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo -e "${GREEN}Download completed!${NC}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 2: EXTRACT TO STAGING & SYNC CLEANLY TO ROOT
# ------------------------------------------------------------------------------
echo -e "${CYAN}[2/3] Extracting and applying system & overlay files...${NC}"

/etc/init.d/3ginfo-lite stop 2>/dev/null
/etc/init.d/tailscale stop 2>/dev/null
killall -9 sms_tool 3ginfo.sh 2>/dev/null
umount -l /www/tinyfm/rootfs/tmp 2>/dev/null
umount -l /www/tinyfm/rootfs 2>/dev/null

mkdir -p "$STAGE_DIR"
if ! tar -xzf "$BACKUP_FILE" -C "$STAGE_DIR" 2>/dev/null; then
    echo -e "${RED}ERROR: Failed to extract aw1000_ultra_mod.tar.gz!${NC}"
    rm -rf "$BACKUP_FILE" "$STAGE_DIR"
    exit 1
fi
rm -f "$BACKUP_FILE"

# Determine source root (handles archives packed from /overlay/upper or /)
if [ -d "$STAGE_DIR/overlay/upper" ]; then
    SRC_ROOT="$STAGE_DIR/overlay/upper"
elif [ -d "$STAGE_DIR/upper" ]; then
    SRC_ROOT="$STAGE_DIR/upper"
else
    SRC_ROOT="$STAGE_DIR"
fi

# Strip runtime symlinks, host keys, and personal accounts from staging before copying
rm -rf "$SRC_ROOT/overlay" "$SRC_ROOT/work" 2>/dev/null
rm -f "$SRC_ROOT/etc/collectd.conf" "$SRC_ROOT/etc/resolv.conf" "$SRC_ROOT/etc/TZ" 2>/dev/null
rm -f "$SRC_ROOT/etc/uhttpd.key" "$SRC_ROOT/etc/uhttpd.crt" 2>/dev/null
rm -f "$SRC_ROOT/etc/dropbear/dropbear_"*_host_key "$SRC_ROOT/etc/dropbear/authorized_keys" 2>/dev/null
rm -f "$SRC_ROOT/etc/3ginfo-lite/"*.state 2>/dev/null
rm -rf "$SRC_ROOT/etc/tailscale/"* "$SRC_ROOT/var/lib/tailscale/"* 2>/dev/null

# Copy staged files into live root filesystem (preserves OverlayFS inode consistency)
cp -af "$SRC_ROOT/." / 2>/dev/null
rm -rf "$STAGE_DIR"

# Refresh OverlayFS mount caches so sed and uci never hit Stale file handle or I/O error
mount -o remount / 2>/dev/null

# Restore web & script permissions
chmod 755 /www /www/tinyfm 2>/dev/null
chmod -R 755 /www/cgi-bin /www/luci-static 2>/dev/null
chmod 644 /www/tinyfm/*.php 2>/dev/null
chmod +x /usr/bin/* /etc/init.d/* /root/*.sh 2>/dev/null
chmod 664 /etc/profile 2>/dev/null
chmod 775 /etc/profile.d /etc/profile.d/* 2>/dev/null

# Fix license validation to accept XXXX-XXXX (with dash)
if [ -f /usr/lib/lua/luci/controller/license.lua ]; then
    cat /usr/lib/lua/luci/controller/license.lua | \
      sed 's/input_kode:gsub("%s+", "")/input_kode:gsub("[%s%-]+", "")/' > /tmp/license.lua.tmp && \
      mv /tmp/license.lua.tmp /usr/lib/lua/luci/controller/license.lua
fi

# Persist TinyFM rootfs recursive bind mount safely without sed -i temp-file rename issues
mkdir -p /www/tinyfm/rootfs
mount --rbind / /www/tinyfm/rootfs 2>/dev/null
if [ -f /etc/rc.local ]; then
    grep -v "/www/tinyfm/rootfs" /etc/rc.local > /tmp/rc.local.tmp
    if grep -q "^exit 0" /tmp/rc.local.tmp; then
        awk '/^exit 0/{print "mount --rbind / /www/tinyfm/rootfs"}1' /tmp/rc.local.tmp > /etc/rc.local
    else
        cat /tmp/rc.local.tmp > /etc/rc.local
        echo "mount --rbind / /www/tinyfm/rootfs" >> /etc/rc.local
    fi
    rm -f /tmp/rc.local.tmp
    chmod +x /etc/rc.local
fi

echo "1.0" > /etc/aw1kv2_version
echo -e "${GREEN}All packages, themes, and configurations applied!${NC}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 3: RESET LICENSE, TAILSCALE, LAN IP & REBOOT
# ------------------------------------------------------------------------------
echo -e "${CYAN}[3/3] Finalizing installation and rebooting modem...${NC}"

# Reset Tailscale state completely
rm -rf /etc/tailscale/* /var/lib/tailscale/* 2>/dev/null

# Force license status to unactivated (0) so buyer sees activation screen
printf "config license 'status'\n\toption activated '0'\n" > /etc/config/woobz_license
uci set woobz_license.status.activated='0' 2>/dev/null
uci commit woobz_license 2>/dev/null

# Reset LAN IP to 192.168.1.1
uci set network.lan.ipaddr='192.168.1.1' 2>/dev/null
uci commit network 2>/dev/null

# Clear LuCI caches
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/* 2>/dev/null

echo -e "${GREEN}  INSTALLATION COMPLETED SUCCESSFULLY!              ${NC}"
echo -e "${YELLOW}  Modem will reboot in 3 seconds. Access LuCI at    ${NC}"
echo -e "${YELLOW}  http://192.168.1.1 after 1-2 minutes.             ${NC}"
echo -e "${CYAN}====================================================${NC}"

rm -f "$0" /tmp/install_mod.sh
sleep 3
sync && reboot
