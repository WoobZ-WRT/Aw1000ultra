#!/bin/sh

DOWNLOAD_URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/download/v1.3/aw1000_ultra_mod.tar.gz"
rm -f /tmp/update_mod.tar.gz

# Download v1.3 CSS patch via IPv4 using curl (fallback to wget if unavailable)
if command -v curl >/dev/null 2>&1; then
    curl -4 -fsL --retry 3 --retry-delay 2 --connect-timeout 15 -k -o /tmp/update_mod.tar.gz "$DOWNLOAD_URL"
else
    wget -qO /tmp/update_mod.tar.gz -T 20 --no-check-certificate "$DOWNLOAD_URL"
fi

if tar -xzf /tmp/update_mod.tar.gz -C / 2>/dev/null; then
    rm -f /tmp/update_mod.tar.gz
else
    echo "Error: Failed to download or extract the v1.3 update package from GitHub."
    rm -f /tmp/update_mod.tar.gz
    exit 1
fi

# Ensure static theme permissions are valid
chmod 755 /www
chmod -R 755 /www/luci-static

# Update version number and flush to flash
echo "1.3" > /etc/aw1kv2_version
sync

# Clear LuCI cache and restart uhttpd safely after response is sent
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/
(sleep 2 && /etc/init.d/uhttpd restart) </dev/null >/dev/null 2>&1 &

echo "=========================================="
echo "  SUCCESS! Updated to v1.3.               "
echo "  Please clear cache & refresh browser.   "
echo "=========================================="
exit 0
