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
