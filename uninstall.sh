#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/lib.sh"

confirm_uninstall() {
    local android_home
    android_home=$(get_android_home)
    local rc_file
    rc_file=$(detect_shell_rc)

    echo ""
    echo "[!] This will remove:"
    echo "    - Android SDK ($android_home)"
    echo "    - AVDs (A10, A14PR)"
    echo "    - Pentesting tools (frida-tools, objection, frida, apkleaks)"
    echo "    - Environment entries from $rc_file"
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

    local android_home
    android_home=$(get_android_home)
    local rc_file
    rc_file=$(detect_shell_rc)

    log_info "Stopping emulators..."
    pkill -f "emulator.*-avd" 2>/dev/null || true

    log_info "Removing AVDs..."
    if command -v avdmanager >/dev/null 2>&1; then
        avdmanager delete avd -n "A10" 2>/dev/null || true
        avdmanager delete avd -n "A14PR" 2>/dev/null || true
    else
        for dir in "$HOME/.android/avd" "$HOME/.config/.android/avd"; do
            rm -rf "$dir/A10.avd" "$dir/A10.ini" 2>/dev/null || true
            rm -rf "$dir/A14PR.avd" "$dir/A14PR.ini" 2>/dev/null || true
        done
    fi

    log_info "Removing Android SDK..."
    rm -rf "$android_home" 2>/dev/null || true

    log_info "Removing symlink..."
    [[ -L "$HOME/.android" ]] && rm -f "$HOME/.android"

    log_info "Uninstalling pentesting tools..."
    if command -v pipx >/dev/null 2>&1; then
        pipx uninstall frida-tools 2>/dev/null || true
        pipx uninstall objection 2>/dev/null || true
        pipx uninstall frida 2>/dev/null || true
        pipx uninstall apkleaks 2>/dev/null || true
    fi

    log_info "Cleaning $rc_file..."
    if [[ -f "$rc_file" ]]; then
        cp "$rc_file" "${rc_file}.backup"
        sed -i '/# Android SDK Paths/d' "$rc_file"
        sed -i '/export ANDROID_HOME/d' "$rc_file"
        sed -i '/android_sdk\/cmdline-tools/d' "$rc_file"
        sed -i '/android_sdk\/platform-tools/d' "$rc_file"
        sed -i '/android_sdk\/emulator/d' "$rc_file"
        sed -i '/# Android Emulator Aliases/d' "$rc_file"
        sed -i '/alias A10=/d' "$rc_file"
        sed -i '/alias A14PR=/d' "$rc_file"
    fi

    log_info "Cleaning downloaded files..."
    rm -f platform-tools.zip cmdline-tools.zip Magisk.apk Magisk.zip burp.cer 2>/dev/null || true
    rm -f ./*.0 2>/dev/null || true

    log_ok "Uninstall completed"
    echo ""
    echo "Note: jdk and python-pipx were not removed"
    echo "Run: source $rc_file"
}

main "$@"
