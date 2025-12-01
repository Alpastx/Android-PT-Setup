#!/bin/bash

set -euo pipefail

confirm_uninstall() {
    echo ""
    echo "[!] This will remove:"
    echo "    - Android SDK (~/$HOME/android_sdk)"
    echo "    - AVDs (A10, A14PR)"
    echo "    - Pentesting tools (frida-tools, objection, frida, apkleaks)"
    echo "    - Environment entries from ~/.zshrc"
    echo ""
    read -rp "Continue? [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) echo "[*] Cancelled."; exit 0 ;;
    esac
}

main() {
    if [[ "${1:-}" != "--force" ]] && [[ "${1:-}" != "-f" ]]; then
        confirm_uninstall
    fi

    echo "[*] Stopping emulators..."
    pkill -f "emulator.*-avd" 2>/dev/null || true

    echo "[*] Removing AVDs..."
    if command -v avdmanager >/dev/null 2>&1; then
        avdmanager delete avd -n "A10" 2>/dev/null || true
        avdmanager delete avd -n "A14PR" 2>/dev/null || true
    else
        rm -rf "$HOME/.android/avd/A10.avd" "$HOME/.android/avd/A10.ini" 2>/dev/null || true
        rm -rf "$HOME/.android/avd/A14PR.avd" "$HOME/.android/avd/A14PR.ini" 2>/dev/null || true
        rm -rf "$HOME/.config/.android/avd/A10.avd" "$HOME/.config/.android/avd/A10.ini" 2>/dev/null || true
        rm -rf "$HOME/.config/.android/avd/A14PR.avd" "$HOME/.config/.android/avd/A14PR.ini" 2>/dev/null || true
    fi

    echo "[*] Removing Android SDK..."
    rm -rf "$HOME/android_sdk" 2>/dev/null || true

    echo "[*] Removing symlink..."
    [[ -L "$HOME/.android" ]] && rm -f "$HOME/.android"

    echo "[*] Uninstalling pentesting tools..."
    if command -v pipx >/dev/null 2>&1; then
        pipx uninstall frida-tools 2>/dev/null || true
        pipx uninstall objection 2>/dev/null || true
        pipx uninstall frida 2>/dev/null || true
        pipx uninstall apkleaks 2>/dev/null || true
    fi

    echo "[*] Cleaning ~/.zshrc..."
    if [[ -f "$HOME/.zshrc" ]]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
        sed -i '/# Android SDK Paths/d' "$HOME/.zshrc"
        sed -i '/export ANDROID_HOME/d' "$HOME/.zshrc"
        sed -i '/android_sdk\/cmdline-tools/d' "$HOME/.zshrc"
        sed -i '/android_sdk\/platform-tools/d' "$HOME/.zshrc"
        sed -i '/android_sdk\/emulator/d' "$HOME/.zshrc"
        sed -i '/# Android Emulator Aliases/d' "$HOME/.zshrc"
        sed -i "/alias A10=/d" "$HOME/.zshrc"
        sed -i "/alias A14PR=/d" "$HOME/.zshrc"
    fi

    echo "[*] Cleaning downloaded files..."
    rm -f platform-tools.zip cmdline-tools.zip Magisk.apk Magisk.zip burp.cer 2>/dev/null || true
    rm -f ./*.0 2>/dev/null || true

    echo "[✓] Uninstall completed"
    echo ""
    echo "Note: jdk and python-pipx were not removed"
    echo "Run: source ~/.zshrc"
}

main "$@"
