#!/bin/bash

set -euo pipefail

show_available_avds() {
    echo "Available AVDs:"
    if command -v avdmanager >/dev/null 2>&1; then
        avdmanager list avd 2>/dev/null | grep "Name:" | cut -d ":" -f 2 || echo "  (none found)"
    else
        echo "  (avdmanager not in PATH)"
    fi
}

show_usage() {
    echo "Usage: $0 <AVD_NAME>"
    echo ""
    echo "Supported AVDs:"
    echo "  A10    - Android 10 with Burp certificate"
    echo "  A14PR  - Android 14 Pro with Magisk root"
    echo ""
    show_available_avds
}

A10() {
    echo "[*] Setting up Android 10 AVD with Burp certificate"
    
    

    # Check and install OpenSSL if needed
    if ! command -v openssl >/dev/null 2>&1; then
        echo "[*] OpenSSL not found, installing..."
        if ! command -v yay >/dev/null 2>&1; then
            echo "[!] yay not found. Please install yay first"
            return 1
        fi
        if ! yay -S --noconfirm openssl; then
            echo "[!] Failed to install OpenSSL"
            return 1
        fi
    fi
    echo "[✓] OpenSSL is installed"

    # Generate certificate files
    echo "[*] Converting certificate to Android format..."
    if ! openssl x509 -inform der -in burp.der -out burp.cer >/dev/null 2>&1; then
        echo "[!] Failed to convert certificate"
        return 1
    fi

    # Generate hash and prepare certificate
    local hash
    hash=$(openssl x509 -inform PEM -subject_hash_old -in burp.cer | head -1)
    cp burp.cer "${hash}.0"
    echo "[✓] Certificate prepared: ${hash}.0"
    echo "[*] Starting Android 10 emulator..."
    emulator -avd A10 -writable-system >/dev/null 2>&1 &

    echo "[*] Waiting for emulator to start..."
    adb wait-for-device
    sleep 10
    echo "[*] Preparing system for certificate installation..."
    adb root
    sleep 5
    adb shell avbctl disable-verification
    adb reboot
    echo "[*] Waiting for device to reboot..."
    adb wait-for-device
    sleep 10
    echo "[*] Installing certificate..."
    adb root
    sleep 5
    adb remount
    if ! adb push "${hash}.0" /system/etc/security/cacerts/; then
        echo "[!] Failed to push certificate"
        return 1
    fi
    adb shell chmod 644 "/system/etc/security/cacerts/${hash}.0"
    echo "[*] Applying changes..."
    adb reboot
    sleep 20
    echo "[*] Cleaning up..."
    pkill -f "emulator.*-avd" || true
    rm -f burp.cer "${hash}.0"
    echo "[✓] Android 10 AVD setup completed successfully"
}

# Function to root Android 14
A14PR() {
    echo "[*] Setting up Android 14 Pro emulator with root"

    local rootavd_dir="$HOME/android_sdk/rootAVD"
    local system_image="$HOME/android_sdk/system-images/android-34/google_apis_playstore/x86_64/ramdisk.img"

    # Check if rootAVD exists
    if [[ ! -d "$rootavd_dir" ]]; then
        echo "[!] rootAVD directory not found"
        echo "    Please ensure rootAVD is installed in $rootavd_dir"
        return 1
    fi

    # Check for system image
    if [[ ! -f "$system_image" ]]; then
        echo "[!] System image not found: $system_image"
        echo "    Please ensure Android 14 system image is installed"
        return 1
    fi

    echo "[*] Starting Android 14 emulator..."
    emulator -avd A14PR >/dev/null 2>&1 &
    
    echo "[*] Waiting for emulator to boot..."
    adb wait-for-device
    sleep 30

    echo "[*] Rooting Android 14 emulator..."
    # Run in subshell to avoid changing directory
    (
        cd "$rootavd_dir" || {
            echo "[!] Failed to access rootAVD directory"
            return 1
        }
        ./rootAVD.sh system-images/android-34/google_apis_playstore/x86_64/ramdisk.img
    ) || {
        echo "[!] Failed to root the emulator"
        return 1
    }

    echo "[*] Waiting for root process to complete..."
    sleep 10

    echo "[*] Rebooting emulator to apply changes..."
    adb reboot

    echo "[✓] Android 14 emulator has been rooted successfully"
    echo "[*] The emulator will restart automatically"
    echo "[*] After restart, Magisk will be available in the system"
}

# Main dispatch
AVD_NAME="${1:-}"

if [[ -z "$AVD_NAME" ]]; then
    echo "[!] Please provide AVD name as argument"
    show_usage
    exit 1
fi

case "$AVD_NAME" in
    A10)    A10 || exit 1 ;;
    A14PR)  A14PR || exit 1 ;;
    -h|--help)
        show_usage
        exit 0
        ;;
    *)
        echo "[!] Unknown AVD name: $AVD_NAME"
        show_available_avds
        exit 1
        ;;
esac

echo "[✓] Setup completed for $AVD_NAME"
