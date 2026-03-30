#!/bin/bash

set -euo pipefail

VERIFY_ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$VERIFY_ROOT/lib.sh"

PASS=0
FAIL=0
WARN=0

check_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
check_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }
check_warn() { echo "  [WARN] $*"; WARN=$((WARN + 1)); }

check_command() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        check_pass "$name found: $(command -v "$name")"
    else
        check_fail "$name not found in PATH"
    fi
}

check_command_warn() {
    local name="$1"
    local hint="${2:-}"
    if command -v "$name" >/dev/null 2>&1; then
        check_pass "$name found: $(command -v "$name")"
    else
        check_warn "$name not found${hint:+ — $hint}"
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
    if [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME" ]]; then
        check_pass "ANDROID_HOME set and directory exists: $ANDROID_HOME"
    elif [[ -d "$HOME/android_sdk" ]]; then
        check_warn "ANDROID_HOME not set — export it or run: source $rc_file (using $HOME/android_sdk for checks)"
    else
        check_fail "ANDROID_HOME not set and $HOME/android_sdk missing"
    fi

    check_dir "$android_home" "Android SDK directory ($android_home)"

    echo ""
    echo "=== Host prerequisites (setup.sh) ==="
    check_command "git"
    check_command "pipx"
    check_command "openssl"
    if command -v jadx >/dev/null 2>&1; then
        check_pass "jadx found: $(command -v jadx)"
    else
        check_warn "jadx not in PATH (optional; install distro package for decompilation)"
    fi

    echo ""
    echo "=== SDK Tools ==="
    check_command "adb"
    if command -v emulator >/dev/null 2>&1; then
        check_pass "emulator found: $(command -v emulator)"
    else
        check_warn "emulator not in PATH — install with: sdkmanager --install \"emulator\" (then ensure PATH includes \$ANDROID_HOME/emulator)"
    fi
    check_command "sdkmanager"
    check_command "avdmanager"

    echo ""
    echo "=== Pentesting tools (pipx) ==="
    check_command "frida"
    check_command "objection"
    check_command "apkleaks"
    if command -v pyapktool >/dev/null 2>&1; then
        check_pass "pyapktool found: $(command -v pyapktool)"
    elif command -v apktool >/dev/null 2>&1; then
        check_pass "apktool found (standalone): $(command -v apktool)"
    else
        check_warn "neither pyapktool nor apktool in PATH — setup.sh installs pyapktool via pipx"
    fi

    echo ""
    echo "=== Project files (repo directory) ==="
    if [[ -f "$VERIFY_ROOT/burp.der" ]]; then
        check_pass "burp.der present next to scripts ($VERIFY_ROOT/burp.der)"
    else
        check_warn "burp.der not found at $VERIFY_ROOT/burp.der (required before setup.sh for A10)"
    fi

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
    echo "=== System images ==="
    check_dir "$android_home/system-images/android-29" "Android 10 system image"
    check_dir "$android_home/system-images/android-34" "Android 14 system image"

    echo ""
    echo "=== rootAVD + Magisk ==="
    check_dir "$android_home/rootAVD" "rootAVD directory"
    check_file "$android_home/rootAVD/Magisk.zip" "Magisk.zip (for A14PR / rootAVD)"

    echo ""
    echo "=== Shell configuration ==="
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
    if [[ -f "$rc_file" ]] && grep -q 'alias A14PR=' "$rc_file" 2>/dev/null; then
        check_pass "A14PR alias configured in $rc_file"
    else
        check_warn "A14PR alias not found in $rc_file"
    fi
}

# ─── Live Checks (requires running emulator) ─────────────────────────────────

run_live_checks() {
    local avd_name="$1"

    echo ""
    echo "=== Live check: $avd_name ==="

    if ! adb devices 2>/dev/null | grep -q "emulator"; then
        log_info "Starting $avd_name for live checks..."
        local extra_flags=()
        [[ "$avd_name" == "A10" ]] && extra_flags=("-writable-system")
        start_emulator "$avd_name" "${extra_flags[@]}" || {
            check_fail "$avd_name failed to start"
            return
        }
    fi

    local boot_status
    boot_status=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)
    if [[ "$boot_status" == "1" ]]; then
        check_pass "$avd_name is fully booted"
    else
        check_fail "$avd_name is not fully booted"
        return
    fi

    # Prefer adb root + shell id (matches A10 adb root; A14PR may use su)
    adb root 2>/dev/null || true
    sleep 2
    local shell_id
    shell_id=$(adb shell id 2>/dev/null | tr -d '\r\n' || true)
    if [[ "$shell_id" == *"uid=0"* ]]; then
        check_pass "$avd_name adb shell as root (uid=0)"
    else
        local su_id
        su_id=$(adb shell "su -c id" 2>/dev/null | tr -d '\r\n' || true)
        if [[ "$su_id" == *"uid=0"* ]]; then
            check_pass "$avd_name root via su"
        else
            check_warn "$avd_name root not confirmed (shell id: '${shell_id:-empty}', su: '${su_id:-empty}')"
        fi
    fi

    if adb shell "test -f /data/local/tmp/frida-server" 2>/dev/null; then
        check_pass "$avd_name frida-server at /data/local/tmp/"
    else
        check_warn "$avd_name frida-server not on device (not installed by setup; optional)"
    fi

    local proxy
    proxy=$(adb shell settings get global http_proxy 2>/dev/null | tr -d '\r\n' || true)
    if [[ "$avd_name" == "A10" ]]; then
        if [[ -n "$proxy" && "$proxy" != "null" && "$proxy" != ":0" ]]; then
            check_pass "$avd_name HTTP proxy set: $proxy"
        else
            check_warn "$avd_name HTTP proxy not set (setup configures 10.0.2.2 for Burp)"
        fi
    else
        check_pass "$avd_name proxy check skipped (A14PR: Burp/proxy not applied by this setup)"
    fi

    if [[ "$avd_name" == "A10" ]]; then
        local cert_count
        cert_count=$(adb shell "ls /system/etc/security/cacerts/ 2>/dev/null | wc -l" | tr -d '\r\n ')
        if [[ "$cert_count" =~ ^[0-9]+$ ]] && (( cert_count > 50 )); then
            check_pass "$avd_name system CA store populated ($cert_count entries)"
        else
            check_warn "$avd_name system CA store looks unusual ($cert_count entries)"
        fi
    fi

    if [[ "$avd_name" == "A14PR" ]]; then
        if adb shell "command -v magisk" 2>/dev/null | grep -q "magisk"; then
            check_pass "$avd_name Magisk on device"
        else
            check_warn "$avd_name Magisk binary not found in PATH (may still be installed)"
        fi
    fi

    kill_emulator
    sleep 3
}

# ─── Main ─────────────────────────────────────────────────────────────────────

echo "╔══════════════════════════════════════════════╗"
echo "║   Android-PT-Setup verification              ║"
echo "╚══════════════════════════════════════════════╝"

run_static_checks

if [[ "${1:-}" == "--live" ]]; then
    echo ""
    echo "=== Live checks ==="
    echo "(Starts emulators temporarily; ensure KVM / emulator works.)"
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
    echo "  Some checks failed. Fix the items above or run setup.sh."
    exit 1
fi

echo "  All required checks passed (warnings are informational)."
exit 0
