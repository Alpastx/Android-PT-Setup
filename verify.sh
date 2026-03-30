#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/lib.sh"

PASS=0
FAIL=0
WARN=0

check_pass() { echo "  [PASS] $*"; (( PASS++ )); }
check_fail() { echo "  [FAIL] $*"; (( FAIL++ )); }
check_warn() { echo "  [WARN] $*"; (( WARN++ )); }

check_command() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        check_pass "$name found: $(command -v "$name")"
    else
        check_fail "$name not found in PATH"
    fi
}

check_file() {
    local path="$1"
    local desc="${2:-$path}"
    if [[ -f "$path" ]]; then
        check_pass "$desc exists"
    else
        check_fail "$desc missing: $path"
    fi
}

check_dir() {
    local path="$1"
    local desc="${2:-$path}"
    if [[ -d "$path" ]]; then
        check_pass "$desc exists"
    else
        check_fail "$desc missing: $path"
    fi
}

# ─── Static Checks ───────────────────────────────────────────────────────────

run_static_checks() {
    local android_home
    android_home=$(get_android_home)
    local rc_file
    rc_file=$(detect_shell_rc)

    echo ""
    echo "=== Environment ==="
    if [[ -n "${ANDROID_HOME:-}" ]]; then
        check_pass "ANDROID_HOME set: $ANDROID_HOME"
    else
        check_fail "ANDROID_HOME not set"
    fi
    check_dir "$android_home" "Android SDK directory"

    echo ""
    echo "=== SDK Tools ==="
    check_command "adb"
    check_command "emulator"
    check_command "sdkmanager"
    check_command "avdmanager"

    echo ""
    echo "=== Pentesting Tools ==="
    check_command "frida"
    check_command "objection"
    check_command "apkleaks"

    echo ""
    echo "=== Static Analysis Tools ==="
    if command -v jadx >/dev/null 2>&1; then
        check_pass "jadx found: $(command -v jadx)"
    else
        check_warn "jadx not in PATH (optional; install distro package for decompilation)"
    fi
    check_command "apktool"

    echo ""
    echo "=== AVDs ==="
    if command -v avdmanager >/dev/null 2>&1; then
        local avd_list
        avd_list=$(avdmanager list avd 2>/dev/null || true)
        if echo "$avd_list" | grep -q "A10"; then
            check_pass "AVD 'A10' exists"
        else
            check_fail "AVD 'A10' not found"
        fi
        if echo "$avd_list" | grep -q "A14PR"; then
            check_pass "AVD 'A14PR' exists"
        else
            check_fail "AVD 'A14PR' not found"
        fi
    else
        check_fail "avdmanager not available — cannot check AVDs"
    fi

    echo ""
    echo "=== System Images ==="
    check_dir "$android_home/system-images/android-29" "Android 10 system image"
    check_dir "$android_home/system-images/android-34" "Android 14 system image"

    echo ""
    echo "=== rootAVD ==="
    check_dir "$android_home/rootAVD" "rootAVD directory"
    check_file "$android_home/rootAVD/Magisk.zip" "Magisk.zip"

    echo ""
    echo "=== Shell Configuration ==="
    if [[ -f "$rc_file" ]] && grep -q 'ANDROID_HOME' "$rc_file" 2>/dev/null; then
        check_pass "ANDROID_HOME configured in $rc_file"
    else
        check_fail "ANDROID_HOME not found in $rc_file"
    fi
    if [[ -f "$rc_file" ]] && grep -q 'alias A10=' "$rc_file" 2>/dev/null; then
        check_pass "A10 alias configured in $rc_file"
    else
        check_fail "A10 alias not found in $rc_file"
    fi
}

# ─── Live Checks (requires running emulator) ─────────────────────────────────

run_live_checks() {
    local avd_name="$1"

    echo ""
    echo "=== Live Check: $avd_name ==="

    # Check if device is reachable
    if ! adb devices 2>/dev/null | grep -q "emulator"; then
        log_info "Starting $avd_name for live checks..."
        local extra_flags=()
        [[ "$avd_name" == "A10" ]] && extra_flags=("-writable-system")
        start_emulator "$avd_name" "${extra_flags[@]}" || {
            check_fail "$avd_name failed to start"
            return
        }
    fi

    # Boot check
    local boot_status
    boot_status=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)
    if [[ "$boot_status" == "1" ]]; then
        check_pass "$avd_name is fully booted"
    else
        check_fail "$avd_name is not fully booted"
        return
    fi

    # Root check
    local root_id
    root_id=$(adb shell "su -c id" 2>/dev/null | tr -d '\r\n' || true)
    if [[ "$root_id" == *"uid=0"* ]]; then
        check_pass "$avd_name has root access"
    else
        check_warn "$avd_name root access not confirmed (got: '${root_id:-empty}')"
    fi

    # frida-server (optional — not installed by setup; push manually if needed)
    if adb shell "test -f /data/local/tmp/frida-server" 2>/dev/null; then
        check_pass "$avd_name has frida-server at /data/local/tmp/"
    else
        check_warn "$avd_name frida-server not on device (install manually if needed)"
    fi

    # Proxy check
    local proxy
    proxy=$(adb shell settings get global http_proxy 2>/dev/null | tr -d '\r\n' || true)
    if [[ -n "$proxy" && "$proxy" != "null" ]]; then
        check_pass "$avd_name proxy configured: $proxy"
    else
        check_warn "$avd_name proxy not configured"
    fi

    # AVD-specific checks
    if [[ "$avd_name" == "A10" ]]; then
        # Check Burp cert in system CA store
        local cert_count
        cert_count=$(adb shell "ls /system/etc/security/cacerts/ 2>/dev/null | wc -l" | tr -d '\r\n')
        if (( cert_count > 100 )); then
            check_pass "$avd_name has certificates in system CA store ($cert_count certs)"
        else
            check_warn "$avd_name system CA store looks empty ($cert_count certs)"
        fi
    fi

    if [[ "$avd_name" == "A14PR" ]]; then
        # Check Magisk
        if adb shell "command -v magisk" 2>/dev/null | grep -q "magisk"; then
            check_pass "$avd_name has Magisk installed"
        else
            check_warn "$avd_name Magisk binary not found"
        fi
    fi

    # Kill emulator after check
    kill_emulator
    sleep 3
}

# ─── Main ─────────────────────────────────────────────────────────────────────

echo "╔══════════════════════════════════════════════╗"
echo "║   Android-PT-Setup Verification              ║"
echo "╚══════════════════════════════════════════════╝"

run_static_checks

if [[ "${1:-}" == "--live" ]]; then
    echo ""
    echo "=== Running Live Checks ==="
    echo "(This will start emulators temporarily)"
    echo ""
    run_live_checks "A10"
    adb kill-server 2>/dev/null || true
    sleep 3
    run_live_checks "A14PR"
fi

echo ""
echo "════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "════════════════════════════════════════════════"

if (( FAIL > 0 )); then
    echo "  Some checks failed. Run setup.sh to fix issues."
    exit 1
else
    echo "  All checks passed!"
    exit 0
fi
