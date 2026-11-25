#!/bin/sh

DOWNLOAD_URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/latest/download/aw1000_ultra_mod.tar.gz"
rm -f /tmp/update_mod.tar.gz

if command -v curl >/dev/null 2>&1; then
    curl -4 -fsL --retry 3 --retry-delay 2 --connect-timeout 15 -k -o /tmp/update_mod.tar.gz "$DOWNLOAD_URL"
else
    wget -qO /tmp/update_mod.tar.gz -T 20 --no-check-certificate "$DOWNLOAD_URL"
fi

if tar -xzf /tmp/update_mod.tar.gz -C / 2>/dev/null; then
    rm -f /tmp/update_mod.tar.gz
else
    echo "Error: Failed to download or extract the v1.5 update package from GitHub."
    rm -f /tmp/update_mod.tar.gz
    exit 1
fi

chmod 755 /www
chmod -R 755 /www/luci-static

chmod 644 /usr/lib/lua/luci/controller/phone.lua /usr/lib/lua/luci/view/phone.htm /www/luci-static/material/cascade.css 2>/dev/null
chmod +x /etc/init.d/slic_autodetect
/etc/init.d/slic_autodetect enable
/etc/init.d/slic_autodetect restart

# aktivasi Data Usage
chmod 755 /usr/bin/datausage_collector.sh /etc/init.d/datausage 2>/dev/null
chmod 644 /etc/datausage/config \
          /usr/lib/lua/luci/controller/datausage.lua \
          /usr/lib/lua/luci/view/admin_status/data_usage_widget.htm \
          /usr/lib/lua/luci/view/admin_status/index.htm 2>/dev/null
/etc/init.d/datausage enable 2>/dev/null
/etc/init.d/datausage start 2>/dev/null


# Update version number and flush to flash
echo "1.5" > /etc/aw1kv2_version
sync

# Clear LuCI cache and restart uhttpd safely after response is sent
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/
(sleep 2 && /etc/init.d/uhttpd restart) </dev/null >/dev/null 2>&1 &

echo "=========================================="
echo "  SUCCESS! Updated to v1.5.               "
echo "  Please clear cache & refresh browser.   "
echo "=========================================="
exit 0
