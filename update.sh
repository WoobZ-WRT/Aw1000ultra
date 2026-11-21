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

# Unmount TinyFM rootfs before extracting to avoid touching active mountpoints
umount -l /www/tinyfm/rootfs/tmp 2>/dev/null
umount -l /www/tinyfm/rootfs 2>/dev/null

if tar -xzf /tmp/update_mod.tar.gz -C / 2>/dev/null; then
    rm -f /tmp/update_mod.tar.gz
else
    echo "Error: Failed to download or extract the update package from GitHub."
    [ -f /tmp/woobz_license.bak ] && mv /tmp/woobz_license.bak /etc/config/woobz_license
    rm -f /tmp/update_mod.tar.gz
    exit 1
fi

# Restore executable & web permissions (prevents 403 Forbidden on LuCI & TinyFM)
chmod 755 /www
chmod -R 755 /www/cgi-bin
chmod -R 755 /www/luci-static
chmod 755 /www/tinyfm 2>/dev/null
chmod 644 /www/tinyfm/*.php 2>/dev/null
chmod +x /usr/bin/* /etc/init.d/* /root/*.sh 2>/dev/null

# Set permissions for terminal profile files and directories
chmod 664 /etc/profile 2>/dev/null
chmod 775 /etc/profile.d 2>/dev/null
chmod 775 /etc/profile.d/* 2>/dev/null

# Mount full root (/) and /tmp non-recursively so Advanced Search scans all root files without loops
mkdir -p /www/tinyfm/rootfs
mount --bind / /www/tinyfm/rootfs
mount --bind /tmp /www/tinyfm/rootfs/tmp

# Persist non-recursive bind mounts in /etc/rc.local for future reboots
if [ -f /etc/rc.local ]; then
    sed -i '/\/www\/tinyfm\/rootfs/d' /etc/rc.local
    if grep -q "^exit 0" /etc/rc.local; then
        sed -i '/^exit 0/i mount --bind / /www/tinyfm/rootfs\nmount --bind /tmp /www/tinyfm/rootfs/tmp' /etc/rc.local
    else
        printf "mount --bind / /www/tinyfm/rootfs\nmount --bind /tmp /www/tinyfm/rootfs/tmp\n" >> /etc/rc.local
    fi
fi

# Enable hidden files & ensure rootfs is NOT excluded in TinyFM config
if [ -f /www/tinyfm/config.php ]; then
    sed -i '/exclude_items/d' /www/tinyfm/config.php
    grep -q "show_hidden" /www/tinyfm/config.php || echo "\$show_hidden = true;" >> /www/tinyfm/config.php
else
    printf "<?php\n\$show_hidden = true;\n" > /www/tinyfm/config.php
fi
chmod 644 /www/tinyfm/config.php 2>/dev/null

# Increase PHP memory & execution limit so scanning all files in root never crashes (default is 8M)
if [ -f /etc/php.ini ]; then
    sed -i 's/^memory_limit = .*/memory_limit = 64M/' /etc/php.ini
    sed -i 's/^max_execution_time = .*/max_execution_time = 120/' /etc/php.ini
fi

# Ensure PHP interpreter & required modules are installed and registered for TinyFM
if [ ! -x /usr/bin/php-cgi ] || [ ! -f /usr/lib/php/json.so ]; then
    opkg update >/dev/null 2>&1
    opkg install php7 php7-cgi php7-mod-ctype php7-mod-dom php7-mod-fileinfo \
                 php7-mod-iconv php7-mod-json php7-mod-mbstring php7-mod-session >/dev/null 2>&1
fi

if [ -x /usr/bin/php-cgi ]; then
    grep -q "\.php=/usr/bin/php-cgi" /etc/config/uhttpd || uci add_list uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci commit uhttpd
fi
# Patch TinyFM Advanced Search (prevent infinite loop on /www/tinyfm/rootfs bind mount)
cat << 'EOF' > /tmp/patch_tinyfm.php
<?php
$new_scan = 'function scan($dir=\'\',$filter=\'\'){$base=rtrim(FM_ROOT_PATH.\'/\'.ltrim($dir,\'/\'),\'/\');$files=array();if(!is_dir($base)||$filter===\'\')return $files;$rx=\'/(\'.str_replace(\'/\',\'\\/\',$filter).\')/i\';$visited=array();$stack=array($base);while(!empty($stack)){$curr=array_pop($stack);$real=@realpath($curr);if($real===false||isset($visited[$real]))continue;$visited[$real]=true;$items=@scandir($curr);if(!is_array($items))continue;foreach($items as $item){if($item===\'.\'||$item===\'..\')continue;$full=$curr.\'/\'.$item;$loc=str_replace(FM_ROOT_PATH,\'\',$curr);if(@preg_match($rx,$item)){$files[]=array("name"=>$item,"type"=>@is_dir($full)?"dir":"file","path"=>$loc);}if(!@is_link($full)&&@is_dir($full)){$stack[]=$full;}if(count($files)>=500)break 2;}}return $files;}';

foreach (array('/www/tinyfm/tinyfm.php', '/www/tinyfm/oceditor.php') as $file) {
    if (!file_exists($file)) continue;
    $code = file_get_contents($file);
    $patched = preg_replace('/function scan\(\$dir=\'\',\$filter=\'\'\)\{.*?return \$files;\}\}/s', $new_scan, $code, 1, $count);
    if ($count > 0 && $patched !== null) {
        file_put_contents($file, $patched);
    }
}
EOF
[ -x /usr/bin/php-cgi ] && php-cgi -q /tmp/patch_tinyfm.php >/dev/null 2>&1
rm -f /tmp/patch_tinyfm.php

# Restore user license and update version number
[ -f /tmp/woobz_license.bak ] && mv /tmp/woobz_license.bak /etc/config/woobz_license
echo "1.2" > /etc/aw1kv2_version

# Clear LuCI cache and restart uhttpd safely after response is sent
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/
(sleep 2 && /etc/init.d/uhttpd restart) </dev/null >/dev/null 2>&1 &

echo "=========================================="
echo "  SUCCESS! Updated to v1.2.               "
echo "  Please refresh your browser.            "
echo "=========================================="
exit 0
