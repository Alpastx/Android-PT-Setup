#!/bin/bash

# Enable error handling
set -e

#platform tools

echo -e "\n[*] Downloading platform-tools...\n"
curl -L "https://dl.google.com/android/repository/platform-tools-latest-linux.zip" -o platformtools.zip || {
    echo "[!] Failed to download platform-tools"
    exit 1
}
echo -e "\n[*] Platform-tools downloaded successfully\n"

#cmdlinetools

echo -e "[*] Fetching cmdline-tools URL..."
temp_file=$(mktemp)
curl -s https://developer.android.com/studio#cmdline-tools -o "$temp_file" || {
    echo "[!] Failed to fetch Android Studio page"
    rm -f "$temp_file"
    exit 1
}

url=$(grep -oP 'https://dl.google.com/android/repository/commandlinetools-linux-[0-9]+_latest.zip' "$temp_file" | head -n 1)
rm -f "$temp_file"

if [[ -z "$url" ]]; then
    echo "[!] Failed to get cmdline-tools URL"
    exit 1
fi

echo -e "\n[*] Downloading cmdline-tools...\n"
curl -L "$url" -o cmdlinetools.zip || {
    echo "[!] Failed to download cmdline-tools"
    exit 1
}
echo -e "\n[*] Cmdline-tools downloaded successfully\n"

#magisk

echo -e "\n[*] Downloading latest Magisk APK...\n"
latest_json=$(curl -s https://api.github.com/repos/topjohnwu/Magisk/releases/latest) || {
    echo "[!] Failed to fetch Magisk release info"
    exit 1
}

apk_url=$(echo "$latest_json" | grep "browser_download_url" | grep "Magisk-v" | grep ".apk" | head -n 1 | cut -d '"' -f 4)

if [[ -z "$apk_url" ]]; then
    echo "[!] Failed to get Magisk APK URL"
    exit 1
fi

magisk_version=$(echo "$apk_url" | grep -oP 'Magisk-v\K[^-]+')
echo -e "[*] Found Magisk version: ${magisk_version:-latest}\n"

curl -L -o "Magisk.zip" "$apk_url" || {
    echo "[!] Failed to download Magisk APK"
    exit 1
}

echo -e "\n[*] Magisk APK zip downloaded successfully"

