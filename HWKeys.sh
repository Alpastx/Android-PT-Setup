#!/bin/bash

AVD_NAME="$1"

if [[ -z "$AVD_NAME" ]]; then
    echo "Usage: $0 <AVD_NAME>"
    exit 1
fi

CONFIG_FILE="$HOME/.config/.android/avd/${AVD_NAME}.avd/config.ini"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[-] AVD config file not found: $CONFIG_FILE"
    exit 1
fi

echo "[*] Patching $CONFIG_FILE..."

# Remove old entries if they exist
sed -i '/^hw\.keyboard=/d' "$CONFIG_FILE"
sed -i '/^hw\.mainKeys=/d' "$CONFIG_FILE"

# Append hardware key settings
echo "hw.keyboard=yes" >> "$CONFIG_FILE"
echo "hw.mainKeys=yes" >> "$CONFIG_FILE"

echo "[+] Hardware keyboard and main keys enabled for $AVD_NAME."