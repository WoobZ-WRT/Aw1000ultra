#!/bin/sh

URL="https://github.com/WoobZ-WRT/Aw1000ultra/releases/download/v1.3/aw1000_ultra_mod.tar.gz"

echo "Mengunduh pembaruan aw1000_ultra_mod v1.3..."
if wget --no-check-certificate -O /tmp/aw1000_ultra_mod.tar.gz "$URL"; then
    tar -xzf /tmp/aw1000_ultra_mod.tar.gz -C /
    rm -f /tmp/aw1000_ultra_mod.tar.gz
    sync
    echo "=========================================="
    echo "  SUCCESS! Updated to v1.3.               "
    echo "  Please refresh your browser.            "
    echo "=========================================="
    exit 0
else
    rm -f /tmp/aw1000_ultra_mod.tar.gz
    echo "=========================================="
    echo "  FAILED! Gagal mengunduh update v1.3.    "
    echo "  Periksa koneksi internet modem Anda.    "
    echo "=========================================="
    exit 1
fi
