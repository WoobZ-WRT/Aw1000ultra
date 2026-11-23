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
EXCLUDE_FILE="/tmp/tar_exclude.txt"
TAR_ERR_LOG="/tmp/tar_err.log"
DOWNLOAD_URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/download/v1.0/aw1000_ultra_mod.tar.gz"

# ------------------------------------------------------------------------------
# STAGE 1: DOWNLOAD TELSTRA 5G MOD PACKAGE
# ------------------------------------------------------------------------------
echo -e "${CYAN}[1/3] Downloading modification package from GitHub...${NC}"
rm -f "$BACKUP_FILE" "$EXCLUDE_FILE" "$TAR_ERR_LOG"

if command -v curl >/dev/null 2>&1; then
    curl -4 -fL --retry 3 --retry-delay 3 --connect-timeout 15 -k -o "$BACKUP_FILE" "$DOWNLOAD_URL"
else
    wget --no-check-certificate -T 30 -O "$BACKUP_FILE" "$DOWNLOAD_URL"
fi

if [ ! -s "$BACKUP_FILE" ]; then
    echo -e "${RED}ERROR: Download failed or the downloaded file is empty!${NC}"
    echo -e "${YELLOW}Please ensure your modem has an active internet connection.${NC}"
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo -e "${GREEN}Download completed!${NC}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 2: EXTRACT & APPLY MODIFICATION FILES
# ------------------------------------------------------------------------------
echo -e "${CYAN}[2/3] Extracting and applying system & overlay files...${NC}"

/etc/init.d/3ginfo-lite stop 2>/dev/null
killall -9 sms_tool 3ginfo.sh 2>/dev/null
umount -l /www/tinyfm/rootfs/tmp 2>/dev/null
umount -l /www/tinyfm/rootfs 2>/dev/null
mount -o remount /overlay 2>/dev/null
mount -o remount / 2>/dev/null
rm -f /etc/3ginfo-lite/*.state /overlay/upper/etc/3ginfo-lite/*.state 2>/dev/null

# Exclude OverlayFS workdir, runtime symlinks, and host-specific keys
cat << 'EOF' > "$EXCLUDE_FILE"
overlay/work
overlay/work/*
etc/3ginfo-lite/*.state
overlay/upper/etc/3ginfo-lite/*.state
etc/uhttpd.key
etc/uhttpd.crt
overlay/upper/etc/uhttpd.key
overlay/upper/etc/uhttpd.crt
etc/dropbear/dropbear_*_host_key
overlay/upper/etc/dropbear/dropbear_*_host_key
etc/collectd.conf
overlay/upper/etc/collectd.conf
etc/resolv.conf
overlay/upper/etc/resolv.conf
etc/TZ
overlay/upper/etc/TZ
EOF

EXTRACT_OK=0
RETRY=0
MAX_RETRIES=50

while [ "$RETRY" -lt "$MAX_RETRIES" ]; do
    if tar -x -z -X "$EXCLUDE_FILE" -f "$BACKUP_FILE" -C / 2>"$TAR_ERR_LOG"; then
        EXTRACT_OK=1
        break
    fi

    # Handle Stale file handle OR existing symlink collisions in BusyBox tar
    BAD_FILES=$(sed -n \
        -e 's/^tar: can'\''t remove old file \(.*\): Stale file handle$/\1/p' \
        -e 's/^tar: can'\''t create symlink '\''\(.*\)'\'' to .*/\1/p' \
        "$TAR_ERR_LOG")

    if [ -n "$BAD_FILES" ]; then
        echo "$BAD_FILES" | while IFS= read -r f; do
            [ -z "$f" ] && continue
            echo -e "${YELLOW}Resolving conflicting file/symlink: ${f}${NC}"
            rm -rf "/$f" "/overlay/upper/$f" 2>/dev/null
            echo "$f" >> "$EXCLUDE_FILE"
        done
        RETRY=$((RETRY + 1))
    else
        cat "$TAR_ERR_LOG"
        break
    fi
done

if [ "$EXTRACT_OK" -ne 1 ]; then
    echo -e "${RED}ERROR: Failed to extract aw1000_ultra_mod.tar.gz!${NC}"
    rm -f "$BACKUP_FILE" "$EXCLUDE_FILE" "$TAR_ERR_LOG"
    exit 1
fi

rm -f "$BACKUP_FILE" "$EXCLUDE_FILE" "$TAR_ERR_LOG"

# Restore web & script permissions (prevents 403 Forbidden)
chmod 755 /www /www/tinyfm 2>/dev/null
chmod -R 755 /www/cgi-bin /www/luci-static 2>/dev/null
chmod 644 /www/tinyfm/*.php 2>/dev/null
chmod +x /usr/bin/* /etc/init.d/* /root/*.sh 2>/dev/null
chmod 664 /etc/profile 2>/dev/null
chmod 775 /etc/profile.d /etc/profile.d/* 2>/dev/null

# Fix license validation to accept XXXX-XXXX (with dash) & initialize UCI config
[ -f /usr/lib/lua/luci/controller/license.lua ] && \
  sed -i 's/input_kode:gsub("%s+", "")/input_kode:gsub("[%s%-]+", "")/' /usr/lib/lua/luci/controller/license.lua
grep -q "config license 'status'" /etc/config/woobz_license 2>/dev/null || \
  printf "config license 'status'\n\toption activated '0'\n" > /etc/config/woobz_license

# Configure TinyFM rootfs recursive bind mount & persist across reboots
mkdir -p /www/tinyfm/rootfs
mount --rbind / /www/tinyfm/rootfs 2>/dev/null
if [ -f /etc/rc.local ]; then
    sed -i '/\/www\/tinyfm\/rootfs/d' /etc/rc.local
    if grep -q "^exit 0" /etc/rc.local; then
        sed -i '/^exit 0/i mount --rbind / /www/tinyfm/rootfs' /etc/rc.local
    else
        echo "mount --rbind / /www/tinyfm/rootfs" >> /etc/rc.local
    fi
fi

echo "1.0" > /etc/aw1kv2_version
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
rm -f /etc/dropbear/authorized_keys /overlay/upper/etc/dropbear/authorized_keys 2>/dev/null
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/* 2>/dev/null

uci set woobz_license.status.activated='0'
uci commit woobz_license

uci set network.lan.ipaddr='192.168.1.1' && uci commit network

rm -f "$0" /tmp/install_mod.sh
sleep 3
sync && reboot
