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

# Mount full root recursively (--rbind) so all sub-mounts (/overlay, /rom, /mnt, /tmp) are searchable
mkdir -p /www/tinyfm/rootfs
if ! mountpoint -q /www/tinyfm/rootfs 2>/dev/null; then
    mount --rbind / /www/tinyfm/rootfs
fi

# Persist --rbind mount in /etc/rc.local for future reboots
if [ -f /etc/rc.local ]; then
    sed -i '/\/www\/tinyfm\/rootfs/d' /etc/rc.local
    if grep -q "^exit 0" /etc/rc.local; then
        sed -i '/^exit 0/i mount --rbind / /www/tinyfm/rootfs' /etc/rc.local
    else
        echo "mount --rbind / /www/tinyfm/rootfs" >> /etc/rc.local
    fi
fi

# Enable hidden files & ensure no root folders are excluded in TinyFM config
if [ -f /www/tinyfm/config.php ]; then
    sed -i '/exclude_items/d' /www/tinyfm/config.php
    grep -q "show_hidden" /www/tinyfm/config.php || echo "\$show_hidden = true;" >> /www/tinyfm/config.php
else
    printf "<?php\n\$show_hidden = true;\n" > /www/tinyfm/config.php
fi
chmod 644 /www/tinyfm/config.php 2>/dev/null

# Increase PHP memory & execution limit so scanning large directories never crashes
if [ -f /etc/php.ini ]; then
    sed -i 's/^memory_limit = .*/memory_limit = 128M/' /etc/php.ini
    sed -i 's/^max_execution_time = .*/max_execution_time = 180/' /etc/php.ini
fi

# Ensure PHP interpreter & required modules are installed (supports PHP 7 & PHP 8)
if [ ! -x /usr/bin/php-cgi ]; then
    opkg update >/dev/null 2>&1
    opkg install php8 php8-cgi php8-mod-ctype php8-mod-dom php8-mod-fileinfo \
                 php8-mod-iconv php8-mod-mbstring php8-mod-session >/dev/null 2>&1 || \
    opkg install php7 php7-cgi php7-mod-ctype php7-mod-dom php7-mod-fileinfo \
                 php7-mod-iconv php7-mod-json php7-mod-mbstring php7-mod-session >/dev/null 2>&1
fi

if [ -x /usr/bin/php-cgi ]; then
    grep -q "\.php=/usr/bin/php-cgi" /etc/config/uhttpd || uci add_list uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci set uhttpd.main.script_timeout='180'
    uci commit uhttpd
fi

# Patch TinyFM Advanced Search (fast BusyBox find + anti-loop fallback + iframe token bypass)
cat << 'EOF' > /tmp/patch_tinyfm.php
<?php
$marker_start = '// BEGIN_WOOBZ_SEARCH_PATCH';
$marker_end   = '// END_WOOBZ_SEARCH_PATCH';

$search_handler = $marker_start . "\n" . <<<'CODE'
if (isset($_REQUEST['type']) && $_REQUEST['type'] === 'search') {
    @ini_set('display_errors', '0');
    while (@ob_get_level() > 0) {
        @ob_end_clean();
    }
    $dir = (isset($_REQUEST['path']) && $_REQUEST['path'] !== '.') ? $_REQUEST['path'] : '';
    $clean_dir = function_exists('fm_clean_path') ? fm_clean_path($dir) : trim($dir, '/');
    $query = isset($_REQUEST['content']) ? $_REQUEST['content'] : '';
    $response = scan($clean_dir, $query);
    header('Content-Type: text/plain; charset=utf-8');
    header('Cache-Control: no-store, no-cache, must-revalidate');
    $flags = defined('JSON_INVALID_UTF8_IGNORE') ? JSON_INVALID_UTF8_IGNORE : 0;
    $json = json_encode($response, $flags);
    echo ($json !== false) ? $json : '[]';
    exit();
}
CODE
. "\n" . $marker_end;

$new_scan = <<<'CODE'
function scan($dir = '', $filter = '') {
    @ini_set('display_errors', '0');
    while (@ob_get_level() > 0) {
        @ob_end_clean();
    }
    $files = array();
    $filter = trim((string)$filter);
    if ($filter === '') {
        return $files;
    }

    $root = rtrim(FM_ROOT_PATH, '/');
    if ($root === '') {
        $root = '/';
    }

    $sub = trim((string)$dir, '/');
    if ($sub === '' || $sub === '.') {
        $base = $root;
    } else {
        $base = ($root === '/' ? '' : $root) . '/' . $sub;
    }

    if (!@is_dir($base)) {
        return $files;
    }

    $prune_paths = array(
        '/proc', '/sys', '/dev',
        '/www/tinyfm/rootfs/proc',
        '/www/tinyfm/rootfs/sys',
        '/www/tinyfm/rootfs/dev',
        '/www/tinyfm/rootfs/www/tinyfm/rootfs'
    );

    // Primary fast search using OpenWrt BusyBox find
    $disabled = (string)@ini_get('disable_functions');
    if (function_exists('shell_exec') && stripos($disabled, 'shell_exec') === false) {
        $is_plain = (bool)preg_match('/^[a-zA-Z0-9._\- ]+$/', $filter);
        $cmd = 'find ' . escapeshellarg($base)
             . ' \( -path ' . escapeshellarg($root . '/proc')
             . ' -o -path ' . escapeshellarg($root . '/sys')
             . ' -o -path ' . escapeshellarg($root . '/dev')
             . ' -o -path ' . escapeshellarg($root . '/www/tinyfm/rootfs')
             . ' -o -path "/proc" -o -path "/sys" -o -path "/dev" \) -prune -o ';

        if ($is_plain) {
            $cmd .= '-iname ' . escapeshellarg('*' . $filter . '*') . ' -print 2>/dev/null | head -n 500';
        } else {
            $cmd .= '-print 2>/dev/null';
        }

        $out = @shell_exec($cmd);
        if (is_string($out)) {
            $rx = '/(' . str_replace('/', '\/', $filter) . ')/i';
            $lines = explode("\n", trim($out));
            foreach ($lines as $full) {
                if ($full === '' || $full === $base) continue;
                $name = basename($full);
                if (!$is_plain && @preg_match($rx, $name) !== 1) continue;
                $parent = dirname($full);
                $loc = ($root === '/') ? $parent : str_replace($root, '', $parent);
                if ($loc === '/') $loc = '';
                $files[] = array(
                    'name' => $name,
                    'type' => @is_dir($full) ? 'dir' : 'file',
                    'path' => $loc
                );
                if (count($files) >= 500) break;
            }
            return $files;
        }
    }

    // Fallback iterative PHP scandir (anti-loop)
    $rx = '/(' . str_replace('/', '\/', $filter) . ')/i';
    $visited = array();
    $stack = array($base);

    while (!empty($stack)) {
        $curr = array_pop($stack);
        $real = @realpath($curr);
        if ($real === false || isset($visited[$real])) continue;
        $visited[$real] = true;

        $items = @scandir($curr);
        if (!is_array($items)) continue;

        foreach ($items as $item) {
            if ($item === '.' || $item === '..') continue;
            $full = ($curr === '/' ? '' : $curr) . '/' . $item;
            if (in_array($full, $prune_paths, true)) continue;

            $loc = ($root === '/') ? $curr : str_replace($root, '', $curr);
            if ($loc === '/') $loc = '';

            if (@preg_match($rx, $item) === 1) {
                $files[] = array(
                    'name' => $item,
                    'type' => @is_dir($full) ? 'dir' : 'file',
                    'path' => $loc
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

function replace_scan_fn($code, $replacement) {
    if (!preg_match('/\bfunction\s+scan\s*\(/', $code, $m, PREG_OFFSET_CAPTURE)) {
        return $code;
    }
    $start = $m[0][1];
    $brace_open = strpos($code, '{', $start);
    if ($brace_open === false) {
        return $code;
    }
    $len = strlen($code);
    $depth = 0;
    $in_single = false;
    $in_double = false;
    $in_line_comment = false;
    $in_block_comment = false;

    for ($i = $brace_open; $i < $len; $i++) {
        $ch = $code[$i];
        $next = ($i + 1 < $len) ? $code[$i + 1] : '';

        if ($in_line_comment) {
            if ($ch === "\n") $in_line_comment = false;
            continue;
        }
        if ($in_block_comment) {
            if ($ch === '*' && $next === '/') {
                $in_block_comment = false;
                $i++;
            }
            continue;
        }
        if ($in_single) {
            if ($ch === '\\') { $i++; continue; }
            if ($ch === "'") $in_single = false;
            continue;
        }
        if ($in_double) {
            if ($ch === '\\') { $i++; continue; }
            if ($ch === '"') $in_double = false;
            continue;
        }

        if ($ch === '/' && $next === '/') { $in_line_comment = true; $i++; continue; }
        if ($ch === '/' && $next === '*') { $in_block_comment = true; $i++; continue; }
        if ($ch === "'") { $in_single = true; continue; }
        if ($ch === '"') { $in_double = true; continue; }

        if ($ch === '{') {
            $depth++;
        } elseif ($ch === '}') {
            $depth--;
            if ($depth === 0) {
                return substr_replace($code, $replacement, $start, ($i - $start) + 1);
            }
        }
    }
    return $code;
}

$targets = glob('/www/tinyfm/*.php');
if (!is_array($targets)) $targets = array();

foreach ($targets as $file) {
    if (basename($file) === 'config.php') continue;
    $orig = file_get_contents($file);
    if ($orig === false || strpos($orig, 'FM_ROOT_PATH') === false) continue;

    $code = $orig;
    // Remove previous patch block if re-running
    $code = preg_replace('/' . preg_quote($marker_start, '/') . '.*?' . preg_quote($marker_end, '/') . '\s*/s', '', $code);

    // Inject search handler immediately after FM_ROOT_PATH is defined
    $code = preg_replace(
        '/(define\s*\(\s*[\'"]FM_ROOT_PATH[\'"]\s*,[^;]+;)/',
        "$1\n" . $search_handler . "\n",
        $code,
        1
    );

    // Replace scan() function safely using brace matching
    $code = replace_scan_fn($code, $new_scan);

    file_put_contents($file, $code);
}
EOF

if command -v php >/dev/null 2>&1; then
    php /tmp/patch_tinyfm.php >/dev/null 2>&1
elif [ -x /usr/bin/php-cgi ]; then
    env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin php-cgi -n -q /tmp/patch_tinyfm.php >/dev/null 2>&1
fi
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
