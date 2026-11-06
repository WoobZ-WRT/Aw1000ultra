#!/bin/sh
echo "Memulai Instalasi Mod Premium AW1000 Ultra..."

if [ ! -f "/tmp/aw1000_ultra_mod.tar.gz" ]; then
    echo "ERROR: File mod.tar.gz tidak ditemukan di folder /tmp/!"
    exit 1
fi

echo "1. Memasang paket aplikasi..."
opkg update
opkg install $(cat /tmp/installed_packages.txt)

echo "2. Menerapkan Tema dan Menu LuCI..."
tar -xzvf /tmp/aw1000_ultra_mod.tar.gz -C /

echo "3. Membersihkan file instalasi agar memori lega..."
rm /tmp/installed_packages.txt /tmp/aw1000_ultra_mod.tar.gz /tmp/install.sh

echo "Instalasi Berhasil! Modem akan otomatis direstart dalam 5 detik..."
sleep 5
reboot
