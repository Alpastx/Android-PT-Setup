#!/bin/bash
AVD_NAME="$1"
if [[ -z "$AVD_NAME" ]]; then
        echo "Usage: $0 <AVD_NAME>"
        exit 1
fi
set -euo pipefail

main() {
    
    local ConfigFile="$HOME/.config/.android/avd/${AVD_NAME}.avd/config.ini"
    if [[ ! -f "$ConfigFile" ]]; then
        echo "[-] AVD config file not found: $ConfigFile"
        exit 1
    else
        echo "[*] Patching $ConfigFile..."
        #remove old entries
        sed -i '/^hw\.keyboard=/d' "$ConfigFile"
        sed -i '/^hw\.mainKeys=/d' "$ConfigFile"
        #append new entries
        echo "hw.keyboard=yes" >> "$ConfigFile"
        echo "hw.mainKeys=yes" >> "$ConfigFile"
        echo "[+] Hardware keyboard and main keys enabled for $AVD_NAME."
    fi
}

main "$@"