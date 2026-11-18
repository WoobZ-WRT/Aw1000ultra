#!/bin/sh
# Back up user license and existing 3ginfo settings before updating
[ -f /etc/config/woobz_license ] && cp /etc/config/woobz_license /tmp/woobz_license.bak
[ -f /etc/config/3ginfo ] && cp /etc/config/3ginfo /tmp/3ginfo.bak

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

# Set permissions for terminal profile and 3ginfo-lite files
chmod 664 /etc/profile 2>/dev/null
chmod 775 /etc/profile.d /etc/profile.d/* 2>/dev/null
chmod -R 755 /usr/share/3ginfo-lite /etc/init.d/3ginfo* 2>/dev/null
chmod +x /usr/bin/sms_tool /usr/bin/gcom /etc/hotplug.d/iface/99-3ginfo-autoset 2>/dev/null

# Enable 3ginfo-lite background services
/etc/init.d/3ginfo_autoset enable >/dev/null 2>&1
/etc/init.d/3ginfo_ttl enable >/dev/null 2>&1
/etc/init.d/3ginfo_sms_forward enable >/dev/null 2>&1

# Ensure PHP interpreter is installed and registered for TinyFM
if [ ! -x /usr/bin/php-cgi ]; then
    opkg update >/dev/null 2>&1
    opkg install php7 php7-cgi >/dev/null 2>&1
fi

if [ -x /usr/bin/php-cgi ]; then
    grep -q "\.php=/usr/bin/php-cgi" /etc/config/uhttpd || uci add_list uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci commit uhttpd
fi

# Restore user license and previous 3ginfo config (if existed)
[ -f /tmp/woobz_license.bak ] && mv /tmp/woobz_license.bak /etc/config/woobz_license
[ -f /tmp/3ginfo.bak ] && mv /tmp/3ginfo.bak /etc/config/3ginfo

[ -f /www/index.html ] && cp /www/index.html /root/index_oem.html.bak
cat << 'EOF' > /www/index.html
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="refresh" content="0; URL=/cgi-bin/luci" />
</head>
<body style="background-color: black">
<a style="color: white; font-family: arial, helvetica, sans-serif; font-size: 12pt" href="/cgi-bin/luci">LuCI - Lua Configuration Interface</a>
</body>
</html>
EOF


# Update firmware version marker
echo "1.3" > /etc/aw1kv2_version

# Reload rpcd ACLs, clear LuCI cache, and safely restart uhttpd
/etc/init.d/rpcd restart >/dev/null 2>&1
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/
(sleep 2 && /etc/init.d/uhttpd restart) >/dev/null 2>&1 &

echo "=========================================="
echo "  SUCCESS! Updated to v1.3.               "
echo "  Please refresh your browser.            "
echo "=========================================="
exit 0
