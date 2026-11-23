URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/download/v1.3/aw1000_ultra_mod.tar.gz"
wget -O /tmp/aw1000_ultra_mod.tar.gz "$URL" && tar -xzf /tmp/aw1000_ultra_mod.tar.gz -C / && rm -f /tmp/aw1000_ultra_mod.tar.gz && sync
echo "=========================================="
echo "  SUCCESS! Updated to v1.3.               "
echo "  Please refresh your browser.            "
echo "=========================================="
exit 0
