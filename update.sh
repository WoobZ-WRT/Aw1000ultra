#!/bin/sh
echo "Memulai proses update WoobZ-WRT..."

# Cadangkan lisensi pembeli agar tidak terkunci ulang setelah update
[ -f /etc/config/woobz_license ] && cp /etc/config/woobz_license /tmp/woobz_license.bak

DOWNLOAD_URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/latest/download/aw1000_ultra_mod.tar.gz"
rm -f /tmp/update_mod.tar.gz

# Unduh paket mod menggunakan curl IPv4 (fallback ke wget jika curl belum ada)
if command -v curl >/dev/null 2>&1; then
    curl -4 -fsL --retry 3 --retry-delay 2 --connect-timeout 15 -k -o /tmp/update_mod.tar.gz "$DOWNLOAD_URL"
else
    wget -qO /tmp/update_mod.tar.gz -T 20 --no-check-certificate "$DOWNLOAD_URL"
fi

if tar -xzf /tmp/update_mod.tar.gz -C / 2>/dev/null; then
    rm -f /tmp/update_mod.tar.gz
else
    echo "Gagal mengunduh atau mengekstrak paket update dari GitHub."
    rm -f /tmp/update_mod.tar.gz
    exit 1
fi

# Atur permission file dan folder tampilan terminal
chmod 664 /etc/profile
chmod 775 /etc/profile.d
chmod 775 /etc/profile.d/*

# Kembalikan lisensi pembeli & perbarui nomor versi
[ -f /tmp/woobz_license.bak ] && mv /tmp/woobz_license.bak /etc/config/woobz_license
echo "1.1" > /etc/aw1kv2_version

rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/
/etc/init.d/uhttpd restart

echo "Update ke v1.1 berhasil! Silakan refresh halaman browser Anda."
