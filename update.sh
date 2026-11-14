#!/bin/sh
echo "Memulai proses update WoobZ-WRT..."

# Cadangkan lisensi pembeli agar tidak terkunci ulang setelah update
[ -f /etc/config/woobz_license ] && cp /etc/config/woobz_license /tmp/woobz_license.bak

# Unduh paket mod dari link Release GitHub Anda
wget -qO /tmp/update_mod.tar.gz --no-check-certificate "https://github.com/WoobZ-WRT/Aw1000ultra/releases/download/v1.0/aw1000_ultra_mod.tar.gz"

if [ -s /tmp/update_mod.tar.gz ]; then
    tar -xzf /tmp/update_mod.tar.gz -C /
    rm -f /tmp/update_mod.tar.gz
else
    echo "Gagal mengunduh paket update."
    exit 1
fi

# Kembalikan lisensi pembeli & perbarui nomor versi
[ -f /tmp/woobz_license.bak ] && mv /tmp/woobz_license.bak /etc/config/woobz_license
echo "1.0" > /etc/aw1kv2_version

rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/
/etc/init.d/uhttpd restart

echo "Update ke v1.0 berhasil! Silakan refresh halaman browser Anda."
