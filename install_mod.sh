#!/bin/sh

# ==============================================================================
# SCRIPT INSTALLER AUTO-MOD TELSTRA 5G (WoobZ-WRT)
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW}      MEMULAI PROSES INSTALASI MOD TELSTRA 5G       ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# TAHAP 1: UPDATE & INSTALASI PAKET PENDUKUNG (Curl, Theme & PHP)
# ------------------------------------------------------------------------------
echo -e "${CYAN}[1/5] Memperbarui repositori dan menginstal paket sistem...${NC}"
opkg update

echo -e "${YELLOW}Menginstal curl & sertifikat SSL (anti-timeout GitHub)...${NC}"
opkg install curl ca-bundle

echo -e "${YELLOW}Menginstal luci-theme-material...${NC}"
opkg install luci-theme-material

echo -e "${YELLOW}Menginstal komponen PHP untuk TinyFM...${NC}"
opkg install php7 php7-cgi php7-mod-ctype php7-mod-dom php7-mod-fileinfo \
             php7-mod-iconv php7-mod-json php7-mod-mbstring php7-mod-session

echo -e "${GREEN}Instalasi paket dasar selesai!${NC}"
echo ""

# ------------------------------------------------------------------------------
# TAHAP 2: UNDUH, EKSTRAKSI & PENERAPAN FILE MODIFIKASI
# ------------------------------------------------------------------------------
echo -e "${CYAN}[2/5] Mengunduh dan menerapkan file sistem modifikasi...${NC}"
BACKUP_FILE="/tmp/aw1000_ultra_mod.tar.gz"
DOWNLOAD_URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/latest/download/aw1000_ultra_mod.tar.gz"

rm -f "$BACKUP_FILE"
echo -e "${YELLOW}Mengunduh file modifikasi dari GitHub server...${NC}"

if command -v curl >/dev/null 2>&1; then
    curl -4 -fL --retry 3 --retry-delay 3 --connect-timeout 15 -k -o "$BACKUP_FILE" "$DOWNLOAD_URL"
else
    wget --no-check-certificate -T 20 -O "$BACKUP_FILE" "$DOWNLOAD_URL"
fi

echo -e "${YELLOW}Menerapkan struktur folder...${NC}"
if ! tar -xzf "$BACKUP_FILE" -C /; then
    echo -e "${RED}ERROR: Gagal mengunduh atau mengekstrak file aw1000_ultra_mod.tar.gz!${NC}"
    echo -e "${YELLOW}Pastikan koneksi internet stabil dan nama aset di GitHub Releases sudah sesuai.${NC}"
    rm -f "$BACKUP_FILE"
    exit 1
fi

rm -f "$BACKUP_FILE"

# Pastikan penanda versi awal tersedia
[ ! -f /etc/aw1kv2_version ] && echo "1.0" > /etc/aw1kv2_version

echo -e "${GREEN}File modifikasi berhasil diterapkan!${NC}"
echo ""

# ------------------------------------------------------------------------------
# TAHAP 3: MEMBUAT SCRIPT AUTO REFRESH IP (cek_wan.sh)
# ------------------------------------------------------------------------------
echo -e "${CYAN}[3/5] Memasang sistem Auto-Refresh IP (Ping Monitor)...${NC}"

cat << 'EOF' > /root/cek_wan.sh
#!/bin/sh

IFACE_TELSTRA="wan"

if [ -f /tmp/wan_cooldown ]; then
    exit 0
fi

if ping -c 3 -W 3 8.8.8.8 > /dev/null; then
    exit 0
else
    logger "Ping Timeout: No internet. Restarting local WAN interface...."
    echo "$(date): Ping Timeout: No internet. Restarting local WAN interface...." >> /root/log_restart_wan.txt

    tail -n 25 /root/log_restart_wan.txt > /tmp/log_temp.txt
    mv /tmp/log_temp.txt /root/log_restart_wan.txt
    
    touch /tmp/wan_cooldown
    ifdown $IFACE_TELSTRA
    sleep 5
    ifup $IFACE_TELSTRA
    sleep 15
    rm -f /tmp/wan_cooldown
fi
EOF

chmod +x /root/cek_wan.sh
sed -i '/cek_wan.sh/d' /etc/crontabs/root

cat << 'EOF' >> /etc/crontabs/root
* * * * * /root/cek_wan.sh
* * * * * sleep 12; /root/cek_wan.sh
* * * * * sleep 24; /root/cek_wan.sh
* * * * * sleep 36; /root/cek_wan.sh
* * * * * sleep 48; /root/cek_wan.sh
EOF

/etc/init.d/cron restart
echo -e "${GREEN}Sistem Auto-Refresh IP aktif!${NC}"
echo ""

# ------------------------------------------------------------------------------
# TAHAP 4: KONFIGURASI HAK AKSES DAN TINYFM BIND MOUNT
# ------------------------------------------------------------------------------
echo -e "${CYAN}[4/5] Mengatur hak akses LuCI dan mengaitkan TinyFM...${NC}"

chmod -R 755 /www/cgi-bin
chmod -R 755 /www/luci-static

mkdir -p /www/tinyfm/rootfs
mount --rbind / /www/tinyfm/rootfs

grep -q "mount --rbind / /www/tinyfm/rootfs" /etc/rc.local || sed -i '/exit 0/i mount --rbind / /www/tinyfm/rootfs' /etc/rc.local

echo -e "${GREEN}Hak akses dan TinyFM siap digunakan!${NC}"
echo ""

# ------------------------------------------------------------------------------
# TAHAP 5: FINISHING & RESTART LAYANAN
# ------------------------------------------------------------------------------
echo -e "${CYAN}[5/5] Menerapkan semua perubahan...${NC}"

rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache/
/etc/init.d/uhttpd restart
/etc/init.d/network restart > /dev/null 2>&1

echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}  INSTALASI SELESAI DENGAN SUKSES!                  ${NC}"
echo -e "${YELLOW}  Silakan muat ulang (refresh) halaman web browser. ${NC}"
echo -e "${CYAN}====================================================${NC}"
exit 0
