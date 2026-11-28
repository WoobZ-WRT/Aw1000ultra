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
# PRE-CHECK: SET DNS, CLEAN STOCK CACHE & VERIFY FREE /OVERLAY SPACE (MIN 60 MB)
# ------------------------------------------------------------------------------
rm -f /etc/resolv.conf 2>/dev/null
printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\n" > /etc/resolv.conf

rm -rf /prebuilt/installed/* /overlay/upper/prebuilt/installed/* 2>/dev/null
FREE_KB=$(df -P /overlay 2>/dev/null | awk 'NR==2 {print $4}')
if [ -n "$FREE_KB" ] && [ "$FREE_KB" -lt 61440 ]; then
    echo -e "${RED}ERROR: Ruang /overlay tidak cukup (tersisa ${FREE_KB}KB, butuh minimal 61440KB).${NC}"
    echo -e "${YELLOW}Jalankan 'firstboot -y && reboot' terlebih dahulu sebelum menginstal mod!${NC}"
    exit 1
fi

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

# Convert OverlayFS whiteout char devices (0,0) into actual deletions before copying
find "$SRC_ROOT" -type c 2>/dev/null | while IFS= read -r w; do
    rel="${w#$SRC_ROOT}"
    rm -f "$rel" "$w" 2>/dev/null
done

# Strip runtime symlinks, host keys, and protect buyer network/RPC/modem configs
rm -rf "$SRC_ROOT/overlay" "$SRC_ROOT/work" "$SRC_ROOT/prebuilt" 2>/dev/null
rm -f "$SRC_ROOT/etc/config/network" "$SRC_ROOT/etc/config/wireless" 2>/dev/null
rm -f "$SRC_ROOT/etc/config/dhcp" "$SRC_ROOT/etc/config/firewall" 2>/dev/null
rm -f "$SRC_ROOT/etc/config/rpcd" "$SRC_ROOT/etc/config/uhttpd" 2>/dev/null
rm -rf "$SRC_ROOT/etc/config/3ginfo"* "$SRC_ROOT/etc/3ginfo"* "$SRC_ROOT/etc/init.d/3ginfo"* 2>/dev/null
rm -f "$SRC_ROOT/etc/board.json" "$SRC_ROOT/etc/ethernet_cfg.txt" 2>/dev/null
rm -f "$SRC_ROOT/etc/collectd.conf" "$SRC_ROOT/etc/resolv.conf" "$SRC_ROOT/etc/TZ" 2>/dev/null
rm -f "$SRC_ROOT/etc/uhttpd.key" "$SRC_ROOT/etc/uhttpd.crt" 2>/dev/null
rm -f "$SRC_ROOT/etc/dropbear/dropbear_"*_host_key "$SRC_ROOT/etc/dropbear/authorized_keys" 2>/dev/null
rm -rf "$SRC_ROOT/etc/tailscale/"* "$SRC_ROOT/var/lib/tailscale/"* 2>/dev/null

# Fix ownership & permissions in RAM ($SRC_ROOT) BEFORE copying to /
chown -hR root:root "$SRC_ROOT" 2>/dev/null
chmod -R a+rX "$SRC_ROOT" 2>/dev/null
find "$SRC_ROOT" -type d -exec chmod 755 {} + 2>/dev/null
chmod 644 "$SRC_ROOT/etc/config/"* 2>/dev/null
chmod -R 755 "$SRC_ROOT/www/cgi-bin" "$SRC_ROOT/www/luci-static" "$SRC_ROOT/usr/libexec/rpcd" "$SRC_ROOT/usr/lib/rpcd" "$SRC_ROOT/usr/share/rpcd" "$SRC_ROOT/usr/share/3ginfo-lite" "$SRC_ROOT/usr/lib/lua/luci" 2>/dev/null
chmod 644 "$SRC_ROOT/usr/share/rpcd/acl.d/"*.json "$SRC_ROOT/www/tinyfm/"*.php 2>/dev/null
chmod +x "$SRC_ROOT/usr/bin/"* "$SRC_ROOT/usr/sbin/"* "$SRC_ROOT/bin/"* "$SRC_ROOT/sbin/"* "$SRC_ROOT/etc/init.d/"* "$SRC_ROOT/root/"*.sh 2>/dev/null
chmod 664 "$SRC_ROOT/etc/profile" 2>/dev/null
chmod 775 "$SRC_ROOT/etc/profile.d" 2>/dev/null
chmod 755 "$SRC_ROOT/etc/profile.d/"* 2>/dev/null
sed -i 's/\r$//' "$SRC_ROOT/usr/libexec/rpcd/"* "$SRC_ROOT/usr/share/3ginfo-lite/"* 2>/dev/null

# Copy staged files into live root filesystem
cp -af "$SRC_ROOT/." / 2>/dev/null
rm -rf "$STAGE_DIR"

# Refresh OverlayFS mount caches
chmod 1777 /tmp 2>/dev/null
mount -o remount / 2>/dev/null

# Strip libtrm debug output from 3ginfo.sh so rpcd always receives pure JSON
if [ -f /usr/share/3ginfo-lite/3ginfo.sh ] && [ ! -f /usr/share/3ginfo-lite/3ginfo_raw.sh ]; then
    mv /usr/share/3ginfo-lite/3ginfo.sh /usr/share/3ginfo-lite/3ginfo_raw.sh
    cat << 'EOF' > /usr/share/3ginfo-lite/3ginfo.sh
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
/usr/share/3ginfo-lite/3ginfo_raw.sh "$@" 2>/dev/null | sed -n "/^{/,9999p"
EOF
    chmod 755 /usr/share/3ginfo-lite/3ginfo.sh /usr/share/3ginfo-lite/3ginfo_raw.sh 2>/dev/null
fi

# Allow background luci.js XHR requests from admin/license safely
if [ -f /usr/lib/lua/luci/dispatcher.lua ]; then
    sed 's|not (request\[1\] == "admin" and request\[2\] == "license") then|not (request[1] == "admin" and request[2] == "license") and not ((luci.http.getenv("HTTP_REFERER") or ""):find("admin/license", 1, true)) then|' \
      /usr/lib/lua/luci/dispatcher.lua > /tmp/dispatcher.lua.tmp
    if [ -s /tmp/dispatcher.lua.tmp ]; then
        mv /tmp/dispatcher.lua.tmp /usr/lib/lua/luci/dispatcher.lua
        chmod 755 /usr/lib/lua/luci/dispatcher.lua 2>/dev/null
    fi
    rm -f /tmp/dispatcher.lua.tmp
fi

# Fix license validation to accept XXXX-XXXX (with dash) and XXXXXXXX
if [ -f /usr/lib/lua/luci/controller/license.lua ]; then
    sed 's/input_kode:gsub("%s+", "")/input_kode:gsub("[%s%-]+", "")/' \
      /usr/lib/lua/luci/controller/license.lua > /tmp/license.lua.tmp
    [ -s /tmp/license.lua.tmp ] && mv /tmp/license.lua.tmp /usr/lib/lua/luci/controller/license.lua
    rm -f /tmp/license.lua.tmp
fi
if [ -f /usr/lib/lua/luci/view/license_view.htm ]; then
    sed 's/maxlength="8"/maxlength="9"/g' \
      /usr/lib/lua/luci/view/license_view.htm > /tmp/license_view.tmp
    [ -s /tmp/license_view.tmp ] && mv /tmp/license_view.tmp /usr/lib/lua/luci/view/license_view.htm
    rm -f /tmp/license_view.tmp
fi

# Configure TinyFM rootfs recursive bind mount & persist across reboots
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

# Enable hidden files & tune PHP limits for full rootfs search
if [ -f /www/tinyfm/config.php ]; then
    grep -v "exclude_items" /www/tinyfm/config.php > /tmp/tfm_cfg.tmp && mv /tmp/tfm_cfg.tmp /www/tinyfm/config.php
    grep -q "show_hidden" /www/tinyfm/config.php || echo "\$show_hidden = true;" >> /www/tinyfm/config.php
else
    printf "<?php\n\$show_hidden = true;\n" > /www/tinyfm/config.php
fi
chmod 644 /www/tinyfm/config.php 2>/dev/null

if [ -f /etc/php.ini ]; then
    sed -e 's/^memory_limit = .*/memory_limit = 64M/' \
        -e 's/^max_execution_time = .*/max_execution_time = 180/' \
        /etc/php.ini > /tmp/php.ini.tmp && mv /tmp/php.ini.tmp /etc/php.ini
fi

# Patch TinyFM Advanced Search (anti-loop scan + bypass iframe token mismatch)
cat << 'EOF' > /tmp/patch_tinyfm.php
<?php
$fn = <<< 'CODE'
function scan($dir = '', $filter = '') {
    @ini_set('display_errors', '0');
    while (@ob_get_level() > 0) { @ob_end_clean(); }
    $base = rtrim(FM_ROOT_PATH . '/' . ltrim($dir, '/'), '/');
    $files = array();
    if (!is_dir($base) || $filter === '') return $files;
    $rx = '/(' . str_replace('/', '\\/', $filter) . ')/i';
    $visited = array();
    $stack = array($base);
    $skip = array(
        '/www/tinyfm/rootfs/proc',
        '/www/tinyfm/rootfs/sys',
        '/www/tinyfm/rootfs/dev',
        '/www/tinyfm/rootfs/www/tinyfm/rootfs'
    );
    while (!empty($stack)) {
        $curr = array_pop($stack);
        $real = @realpath($curr);
        if ($real === false || isset($visited[$real])) continue;
        $visited[$real] = true;
        $items = @scandir($curr);
        if (!is_array($items)) continue;
        foreach ($items as $item) {
            if ($item === '.' || $item === '..') continue;
            $full = $curr . '/' . $item;
            if (in_array($full, $skip, true)) continue;
            $loc = str_replace(FM_ROOT_PATH, '', $curr);
            if (@preg_match($rx, $item)) {
                $n = @iconv('UTF-8', 'UTF-8//IGNORE', $item);
                $p = @iconv('UTF-8', 'UTF-8//IGNORE', $loc);
                $files[] = array(
                    "name" => ($n !== false ? $n : $item),
                    "type" => @is_dir($full) ? "dir" : "file",
                    "path" => ($p !== false ? $p : $loc)
                );
            }
            if (!@is_link($full) && @is_dir($full)) {
                $stack[] = $full;
            }
            if (count($files) >= 500) break 2;
        }
    }
    return $files;
}
CODE;

$sh = <<< 'CODE'
if (isset($_POST['type']) && $_POST['type'] == 'search') {
    $d = (isset($_POST['path']) && $_POST['path'] != '.') ? $_POST['path'] : '';
    $res = scan(fm_clean_path($d), isset($_POST['content']) ? $_POST['content'] : '');
    $out = json_encode($res);
    if ($out === false) $out = '[]';
    header('HTTP/1.1 200 OK', true, 200);
    header('Content-Type: text/plain; charset=utf-8');
    echo $out;
    exit();
}
CODE;

foreach (array('/www/tinyfm/tinyfm.php', '/www/tinyfm/oceditor.php') as $file) {
    if (!file_exists($file)) continue;
    $code = file_get_contents($file);
    $patScan = '/\bfunction\s+scan\s*\([^)]*\)\s*\{.*?return\s+\$files;\s*\}\s*\}/s';
    $code = preg_replace($patScan, $fn, $code, 1);
    if (strpos($code, 'HTTP/1.1 200 OK') === false) {
        $patTok = '/if\s*\(\s*!isset\s*\(\s*\$_POST\s*\[\s*[\'"]token[\'"]\s*\]\s*\)/';
        $code = preg_replace($patTok, $sh . "\n" . '$0', $code, 1);
    }
    $patOld = '/if\s*\(\s*isset\s*\(\s*\$_POST\s*\[\s*[\'"]type[\'"]\s*\]\s*\)\s*'
            . '&&\s*\$_POST\s*\[\s*[\'"]type[\'"]\s*\]\s*==\s*[\'"]search[\'"]\s*\)'
            . '\s*\{.*?exit\s*\(\s*\)\s*;\s*\}/s';
    $code = preg_replace($patOld, $sh, $code, 1);
    file_put_contents($file, $code);
}
EOF

if command -v php >/dev/null 2>&1; then
    php /tmp/patch_tinyfm.php >/dev/null 2>&1
elif [ -x /usr/bin/php-cgi ]; then
    SCRIPT_FILENAME=/tmp/patch_tinyfm.php REDIRECT_STATUS=200 \
      php-cgi -q < /tmp/patch_tinyfm.php >/dev/null 2>&1
fi
rm -f /tmp/patch_tinyfm.php

echo "1.0" > /etc/aw1kv2_version
echo -e "${GREEN}All packages, themes, and configurations applied!${NC}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 3: RESET LICENSE, DNS, TAILSCALE, LAN IP, WIFI & REBOOT
# ------------------------------------------------------------------------------
echo -e "${CYAN}[3/3] Finalizing installation and rebooting modem...${NC}"

# Reset Tailscale state completely
rm -rf /etc/tailscale/* /var/lib/tailscale/* 2>/dev/null
/etc/init.d/tailscale enable 2>/dev/null

# Force license status to unactivated (0) so buyer sees activation screen
printf "config license 'status'\n\toption activated '0'\n" > /etc/config/woobz_license
uci set woobz_license.status.activated='0' 2>/dev/null
uci commit woobz_license 2>/dev/null

# Reset LAN IP to 192.168.1.1 without overwriting buyer Ethernet port mappings
uci set network.lan.ipaddr='192.168.1.1' 2>/dev/null
uci commit network 2>/dev/null

# Set persistent public DNS servers (1.1.1.1 & 8.8.8.8) in dnsmasq
uci -q delete dhcp.@dnsmasq[0].server 2>/dev/null
uci add_list dhcp.@dnsmasq[0].server='1.1.1.1' 2>/dev/null
uci add_list dhcp.@dnsmasq[0].server='8.8.8.8' 2>/dev/null
uci commit dhcp 2>/dev/null

# Set default WoobZ Wi-Fi SSIDs & password safely
uci set wireless.@wifi-iface[0].ssid='AW1000_Ultra' 2>/dev/null
uci set wireless.@wifi-iface[0].encryption='psk2' 2>/dev/null
uci set wireless.@wifi-iface[0].key='password' 2>/dev/null
uci set wireless.@wifi-iface[1].ssid='AW1000_Ultra 5G' 2>/dev/null
uci set wireless.@wifi-iface[1].encryption='psk2' 2>/dev/null
uci set wireless.@wifi-iface[1].key='password' 2>/dev/null
uci commit wireless 2>/dev/null

# Keep stock /etc/config/rpcd and /etc/config/3ginfo intact from /rom
cp -f /rom/etc/config/rpcd /etc/config/rpcd 2>/dev/null
chmod 644 /etc/config/rpcd 2>/dev/null
cp -af /rom/etc/config/3ginfo* /etc/config/ 2>/dev/null
cp -af /rom/etc/3ginfo* /etc/ 2>/dev/null
chmod 644 /etc/config/3ginfo* 2>/dev/null

# Validate /etc/config/luci syntax and apply Material theme safely
if ! uci -q show luci >/dev/null 2>&1; then
    cp -f /rom/etc/config/luci /etc/config/luci 2>/dev/null
fi
if ! uci -q get luci.main.mediaurlbase >/dev/null 2>&1; then
    printf "config core 'main'\n\toption lang 'auto'\n\toption mediaurlbase '/luci-static/bootstrap'\n\toption resourcebase '/luci-static/resources'\n\nconfig internal 'themes'\n\toption Bootstrap '/luci-static/bootstrap'\n" > /etc/config/luci
fi
if [ -d /www/luci-static/material ]; then
    uci set luci.main.mediaurlbase='/luci-static/material' 2>/dev/null
    uci set luci.themes.Material='/luci-static/material' 2>/dev/null
    uci commit luci 2>/dev/null
fi
chmod 644 /etc/config/luci 2>/dev/null

# Ensure core web & RPC services are enabled and clear LuCI caches
/etc/init.d/rpcd enable 2>/dev/null
/etc/init.d/uhttpd enable 2>/dev/null
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/* 2>/dev/null

echo -e "${GREEN}  INSTALLATION COMPLETED SUCCESSFULLY!              ${NC}"
echo -e "${YELLOW}  Modem will reboot in 3 seconds. Access LuCI at    ${NC}"
echo -e "${YELLOW}  http://192.168.1.1 after 1-2 minutes.             ${NC}"
echo -e "${CYAN}====================================================${NC}"

rm -f "$0" /tmp/install_mod.sh
sleep 3
sync && reboot
