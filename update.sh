#!/bin/sh
echo "Memulai proses update WoobZ-WRT..."

# Cadangkan status lisensi pembeli agar tidak terkunci ulang setelah update
[ -f /etc/config/woobz_license ] && cp /etc/config/woobz_license /tmp/woobz_license.bak

wget -qO /tmp/update_mod.tar.gz --no-check-certificate "https://github.com/WoobZ-WRT/NAMA_REPO/releases/latest/download/aw1000_ultra_mod.tar.gz"

if [ -s /tmp/update_mod.tar.gz ]; then
    tar -xzf /tmp/update_mod.tar.gz -C /
    rm -f /tmp/update_mod.tar.gz
else
    echo "Gagal mengunduh paket update."
    exit 1
fi

# Pulihkan status lisensi pembeli & perbarui nomor versi
[ -f /tmp/woobz_license.bak ] && mv /tmp/woobz_license.bak /etc/config/woobz_license
echo "1.1" > /etc/aw1kv2_version

rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/
/etc/init.d/uhttpd restart

echo "Update ke v1.1 berhasil! Silakan refresh browser Anda."
