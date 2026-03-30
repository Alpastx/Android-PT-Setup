#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/lib.sh"

AVD_NAME="${1:-}"
if [[ -z "$AVD_NAME" ]]; then
    echo "Usage: $0 <AVD_NAME>"
    exit 1
fi

main() {
    # Try multiple possible AVD config locations
    local ConfigFile=""
    for dir in "$HOME/.android/avd" "$HOME/.config/.android/avd"; do
        if [[ -f "$dir/${AVD_NAME}.avd/config.ini" ]]; then
            ConfigFile="$dir/${AVD_NAME}.avd/config.ini"
            break
        fi
    done

    if [[ -z "$ConfigFile" ]]; then
        log_fatal "AVD config file not found for '$AVD_NAME' in ~/.android/avd/ or ~/.config/.android/avd/"
    fi

    log_info "Patching $ConfigFile..."
    # remove old entries
    sed -i '/^hw\.keyboard=/d' "$ConfigFile"
    sed -i '/^hw\.mainKeys=/d' "$ConfigFile"
    # append new entries
    echo "hw.keyboard=yes" >> "$ConfigFile"
    echo "hw.mainKeys=yes" >> "$ConfigFile"
    log_ok "Hardware keyboard and main keys enabled for $AVD_NAME"
}

main "$@"
