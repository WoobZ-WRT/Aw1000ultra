#!/bin/sh

# ==============================================================================
# SCRIPT INSTALLER AUTO-MOD TELSTRA 5G
# ==============================================================================

# Pewarnaan teks untuk antarmuka terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW}      MEMULAI PROSES INSTALASI MOD TELSTRA 5G       ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# TAHAP 1: UPDATE & INSTALASI PAKET PENDUKUNG (Theme & PHP)
# ------------------------------------------------------------------------------
echo -e "${CYAN}[1/5] Memperbarui repositori dan menginstal paket sistem...${NC}"
opkg update

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
BACKUP_FILE="aw1000_ultra_mod.tar.gz"
DOWNLOAD_URL="https://raw.githubusercontent.com/WoobZ-WRT/Aw1000ultra/refs/heads/main/aw1000_ultra_mod.tar.gz"

echo -e "${YELLOW}Mengunduh file modifikasi dari GitHub server...${NC}"
# Masuk ke folder /tmp sementara untuk mengunduh
cd /tmp
wget --no-check-certificate -O "$BACKUP_FILE" "$DOWNLOAD_URL"

# Mengecek apakah file berhasil diunduh
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}ERROR: Gagal mengunduh file $BACKUP_FILE dari server!${NC}"
    echo -e "${YELLOW}Pastikan modem memiliki koneksi internet aktif yang stabil.${NC}"
    exit 1
fi

# Ekstrak file tar.gz langsung ke sistem (root /)
echo -e "${YELLOW}Menerapkan struktur folder...${NC}"
tar -xzvf "$BACKUP_FILE" -C / > /dev/null 2>&1

# Menghapus file unduhan tar.gz untuk menghemat memori setelah selesai diekstrak
rm -f "$BACKUP_FILE"

echo -e "${GREEN}File modifikasi berhasil diterapkan!${NC}"
echo ""

# ------------------------------------------------------------------------------
# TAHAP 3: MEMBUAT SCRIPT AUTO REFRESH IP (cek_wan.sh)
# ------------------------------------------------------------------------------
echo -e "${CYAN}[3/5] Memasang sistem Auto-Refresh IP (Ping Monitor)...${NC}"

cat << 'EOF' > /root/cek_wan.sh
#!/bin/sh

# Nama interface di modem Telstra (sesuaikan jika berbeda, misal: wan1 atau mob1s1a1)
IFACE_TELSTRA="wan"

# 1. CEK PENGUNCI: Kalau file ini ada, Cron yang baru datang akan disuruh pulang
if [ -f /tmp/wan_cooldown ]; then
    exit 0
fi

if ping -c 3 -W 3 8.8.8.8 > /dev/null; then
    exit 0
else
    logger "Ping Timeout: No internet. Restarting local WAN interface...."
    
    # Menyimpan catatan jam & tanggal ke file teks permanen
    echo "$(date): Ping Timeout: No internet. Restarting local WAN interface...." >> /root/log_restart_wan.txt

    # Membatasi file log maksimal hanya 25 baris terakhir
    tail -n 25 /root/log_restart_wan.txt > /tmp/log_temp.txt
    mv /tmp/log_temp.txt /root/log_restart_wan.txt
    
    # 2. PASANG PENGUNCI: Menandai bahwa proses restart sedang dimulai
    touch /tmp/wan_cooldown
    
    # EKSEKUSI LANGSUNG
    ifdown $IFACE_TELSTRA
    sleep 5
    ifup $IFACE_TELSTRA
    
    # 3. COOLDOWN 15 DETIK: Jeda aman
    sleep 15
    
    # 4. CABUT PENGUNCI
    rm -f /tmp/wan_cooldown
fi
EOF

# Berikan hak akses eksekusi
chmod +x /root/cek_wan.sh

# Daftarkan ke Crontab (Hapus entry lama jika ada, lalu pasang yang baru)
sed -i '/cek_wan.sh/d' /etc/crontabs/root

cat << 'EOF' >> /etc/crontabs/root
* * * * * /root/cek_wan.sh
* * * * * sleep 12; /root/cek_wan.sh
* * * * * sleep 24; /root/cek_wan.sh
* * * * * sleep 36; /root/cek_wan.sh
* * * * * sleep 48; /root/cek_wan.sh
EOF

# Restart layanan Cron
/etc/init.d/cron restart
echo -e "${GREEN}Sistem Auto-Refresh IP aktif!${NC}"
echo ""

# ------------------------------------------------------------------------------
# TAHAP 4: KONFIGURASI HAK AKSES DAN TINYFM BIND MOUNT
# ------------------------------------------------------------------------------
echo -e "${CYAN}[4/5] Mengatur hak akses LuCI dan mengaitkan TinyFM...${NC}"

# Hak akses web
chmod -R 755 /www/cgi-bin
chmod -R 755 /www/luci-static

# Menyiapkan dan mengaitkan rootfs untuk TinyFM
mkdir -p /www/tinyfm/rootfs
mount --rbind / /www/tinyfm/rootfs

# Memastikan bind mount berjalan otomatis saat router dihidupkan ulang (rc.local)
grep -q "mount --rbind / /www/tinyfm/rootfs" /etc/rc.local || sed -i '/exit 0/i mount --rbind / /www/tinyfm/rootfs' /etc/rc.local

echo -e "${GREEN}Hak akses dan TinyFM siap digunakan!${NC}"
echo ""

# ------------------------------------------------------------------------------
# TAHAP 5: FINISHING & RESTART LAYANAN
# ------------------------------------------------------------------------------
echo -e "${CYAN}[5/5] Menerapkan semua perubahan...${NC}"

# Restart web server untuk menerapkan tema & menu baru
/etc/init.d/uhttpd restart
/etc/init.d/network restart > /dev/null 2>&1

echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}  INSTALASI SELESAI DENGAN SUKSES!                  ${NC}"
echo -e "${YELLOW}  Silakan muat ulang (refresh) halaman web browser. ${NC}"
echo -e "${CYAN}====================================================${NC}"
exit 0
