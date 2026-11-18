#!/bin/sh
# Back up user license to prevent re-locking after the update
[ -f /etc/config/woobz_license ] && cp /etc/config/woobz_license /tmp/woobz_license.bak

DOWNLOAD_URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/latest/download/aw1000_ultra_mod.tar.gz"
rm -f /tmp/update_mod.tar.gz

# Download the mod package via IPv4 using curl (fallback to wget if unavailable)
if command -v curl >/dev/null 2>&1; then
    curl -4 -fsL --retry 3 --retry-delay 2 --connect-timeout 15 -k -o /tmp/update_mod.tar.gz "$DOWNLOAD_URL"
else
    wget -qO /tmp/update_mod.tar.gz -T 20 --no-check-certificate "$DOWNLOAD_URL"
fi

if tar -xzf /tmp/update_mod.tar.gz -C / 2>/dev/null; then
    rm -f /tmp/update_mod.tar.gz
else
    echo "Error: Failed to download or extract the update package from GitHub."
    rm -f /tmp/update_mod.tar.gz
    exit 1
fi

# Set permissions for terminal profile files and directories
chmod 664 /etc/profile
chmod 775 /etc/profile.d
chmod 775 /etc/profile.d/*

# Ensure PHP interpreter is installed and registered for TinyFM
if [ ! -x /usr/bin/php-cgi ]; then
    opkg update >/dev/null 2>&1
    opkg install php7 php7-cgi >/dev/null 2>&1
fi

if [ -x /usr/bin/php-cgi ]; then
    grep -q "\.php=/usr/bin/php-cgi" /etc/config/uhttpd || uci add_list uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci commit uhttpd
fi

# Restore user license and update version number
[ -f /tmp/woobz_license.bak ] && mv /tmp/woobz_license.bak /etc/config/woobz_license
echo "1.2" > /etc/aw1kv2_version

# Clear LuCI cache and reload uhttpd safely after response is sent
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/
(sleep 2 && /etc/init.d/uhttpd restart) >/dev/null 2>&1 &

echo "=========================================="
echo "  SUCCESS! Updated to v1.2.               "
echo "  Please refresh your browser.            "
echo "=========================================="
exit 0
