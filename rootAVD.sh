#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Burp DER: env BURP_DER (set by setup.sh), else file next to this script
burp_der_path() {
    if [[ -n "${BURP_DER:-}" && -f "$BURP_DER" ]]; then
        echo "$BURP_DER"
    elif [[ -f "$SCRIPT_DIR/burp.der" ]]; then
        echo "$SCRIPT_DIR/burp.der"
    elif [[ -n "${PWD:-}" && -f "$PWD/burp.der" ]]; then
        echo "$PWD/burp.der"
    else
        echo ""
    fi
}

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
    log_info "Setting up Android 10 AVD with Burp certificate"

    # Setup cleanup trap
    trap cleanup EXIT

    local burp_der
    burp_der=$(burp_der_path)
    if [[ -z "$burp_der" ]]; then
        log_fatal "burp.der not found — set BURP_DER or place burp.der in $SCRIPT_DIR"
    fi

    if ! command -v openssl >/dev/null 2>&1; then
        log_fatal "OpenSSL (openssl) is required on the host for certificate conversion"
    fi

    # Generate certificate files
    log_info "Converting certificate to Android format..."
    if ! openssl x509 -inform der -in "$burp_der" -out burp.cer 2>/dev/null; then
        log_fatal "Failed to convert certificate. Is burp.der a valid DER certificate?"
    fi
    register_cleanup "burp.cer"

    # Generate hash and validate
    local hash
    hash=$(openssl x509 -inform PEM -subject_hash_old -in burp.cer 2>/dev/null | head -1 | tr -d '\r\n')
    if [[ -z "$hash" || ! "$hash" =~ ^[a-f0-9]+$ ]]; then
        log_fatal "Failed to extract valid certificate hash (got: '${hash:-empty}')"
    fi
    cp burp.cer "${hash}.0"
    register_cleanup "${hash}.0"
    log_ok "Certificate prepared: ${hash}.0"

    # Start emulator with boot detection (replaces sleep-based waiting)
    if ! start_emulator "A10" "-writable-system"; then
        log_fatal "Failed to start A10 emulator"
    fi

    # Root the device and wait for adbd to restart
    log_info "Preparing system for certificate installation..."
    if ! adb_root_and_wait; then
        log_fatal "Failed to get root access"
    fi

    # Disable Android Verified Boot
    log_info "Disabling Android Verified Boot..."
    if ! adb shell avbctl disable-verification 2>/dev/null; then
        log_warn "avbctl disable-verification failed (may already be disabled)"
    fi

    # Reboot and wait for full boot
    log_info "Rebooting to apply AVB changes..."
    adb reboot 2>/dev/null || true
    if ! wait_for_boot 120; then
        log_fatal "Device failed to reboot after AVB disable"
    fi

    # Root again after reboot
    log_info "Re-acquiring root after reboot..."
    if ! adb_root_and_wait; then
        log_fatal "Failed to get root access after reboot"
    fi

    # Remount system partition as read-write
    log_info "Remounting system as read-write..."
    if ! adb remount 2>/dev/null; then
        log_fatal "Failed to remount system partition"
    fi
    sleep 2

    # Push certificate to system CA store
    log_info "Installing certificate to system CA store..."
    if ! adb push "${hash}.0" /system/etc/security/cacerts/; then
        log_fatal "Failed to push certificate to device"
    fi

    # Verify certificate exists on device
    if ! adb shell "test -f /system/etc/security/cacerts/${hash}.0" 2>/dev/null; then
        log_fatal "Certificate not found on device after push"
    fi

    adb shell chmod 644 "/system/etc/security/cacerts/${hash}.0" 2>/dev/null || \
        log_fatal "Failed to set certificate permissions"

    # Configure proxy to point at Burp on host
    configure_proxy || log_warn "Proxy configuration failed — configure manually in Settings"

    # Final reboot to apply
    log_info "Rebooting to apply all changes..."
    adb reboot 2>/dev/null || true
    sleep 5

    # Clean up : kill emulator and temp files
    kill_emulator
    rm -f burp.cer "${hash}.0" 2>/dev/null || true

    # Disable the trap since we cleaned up manually
    trap - EXIT

    log_ok "Android 10 AVD setup completed successfully"
    log_ok "Burp certificate installed to system CA store"
    log_ok "Proxy configured to 10.0.2.2:${BURP_PORT:-8080}"
}

# Function to root Android 14
A14PR() {
    log_info "Setting up Android 14 Pro emulator with Magisk root"

    # Setup cleanup trap
    trap cleanup EXIT

    local android_home
    android_home=$(get_android_home)
    local rootavd_dir="$android_home/rootAVD"
    local system_image="$android_home/system-images/android-34/google_apis_playstore/x86_64/ramdisk.img"

    # Check if rootAVD exists
    if [[ ! -d "$rootavd_dir" ]]; then
        log_fatal "rootAVD directory not found at $rootavd_dir"
    fi

    if [[ ! -x "$rootavd_dir/rootAVD.sh" ]]; then
        chmod +x "$rootavd_dir/rootAVD.sh" 2>/dev/null || \
            log_fatal "rootAVD.sh not found or not executable in $rootavd_dir"
    fi

    # Check for system image
    if [[ ! -f "$system_image" ]]; then
        log_fatal "System image not found: $system_image"
    fi

    # Start emulator and wait for full boot
    if ! start_emulator "A14PR"; then
        log_fatal "Failed to start A14PR emulator"
    fi

    # Run rootAVD to patch ramdisk with Magisk
    log_info "Rooting Android 14 emulator with Magisk..."
    (
        cd "$rootavd_dir" || log_fatal "Failed to access rootAVD directory"
        # Use path relative to ANDROID_HOME (go up from rootAVD/ to android_sdk/)
        ./rootAVD.sh system-images/android-34/google_apis_playstore/x86_64/ramdisk.img
    ) || log_fatal "rootAVD failed to patch ramdisk"

    # Wait for rootAVD to finish and device to come back
    log_info "Waiting for root process to complete..."
    if ! wait_for_boot 120; then
        log_warn "Device may need manual reboot after Magisk install"
        adb reboot 2>/dev/null || true
        wait_for_boot 120 || log_warn "Device did not come back — check emulator manually"
    fi
    # Disable the trap since we're done
    trap - EXIT

    log_ok "Android 14 emulator has been rooted successfully"
}

# Main dispatch
AVD_NAME="${1:-}"

if [[ -z "$AVD_NAME" ]]; then
    log_warn "Please provide AVD name as argument"
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
        log_warn "Unknown AVD name: $AVD_NAME"
        show_available_avds
        exit 1
        ;;
esac

log_ok "Setup completed for $AVD_NAME"
