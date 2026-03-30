#!/bin/bash
# lib.sh — Shared utility library for Android-PT-Setup
# Source this file in all scripts: source "$(dirname "$0")/lib.sh"

# ─── Logging ───────────────────────────────────────────────────────────────────

log_info()  { echo "[*] $*"; }
log_ok()    { echo "[✓] $*"; }
log_warn()  { echo "[!] $*" >&2; }
log_fatal() { echo "[!] $*" >&2; exit 1; }

# ─── Shell Detection ──────────────────────────────────────────────────────────

# Returns the path to the user's shell RC file
detect_shell_rc() {
    local shell_name
    shell_name=$(basename "${SHELL:-/bin/bash}")
    case "$shell_name" in
        zsh)  echo "$HOME/.zshrc" ;;
        bash) echo "$HOME/.bashrc" ;;
        *)    echo "$HOME/.bashrc" ;;
    esac
}

# git and pipx must be installed via the system package manager; jadx is optional (recommended).
prompt_host_prerequisites() {
    echo ""
    echo "This script does not install host packages — use your distro package manager."
    echo "  git   — clone rootAVD (required)"
    echo "  pipx  — frida-tools, objection, apkleaks, pyapktool (required)"
    echo "  jadx  — APK decompilation (optional, recommended)"
    read -rp "Confirm git and pipx are already installed [y/N]: " resp
    case "$resp" in
        [yY][eE][sS]|[yY]) ;;
        *) log_fatal "Install git and pipx, then re-run setup.sh." ;;
    esac
    local missing=()
    local cmd
    for cmd in git pipx; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if (( ${#missing[@]} > 0 )); then
        log_fatal "Not found in PATH: ${missing[*]}"
    fi
    log_ok "Required tools on PATH: git, pipx"
    if command -v jadx >/dev/null 2>&1; then
        log_ok "jadx found on PATH"
    else
        log_warn "jadx not on PATH — install your distro's jadx package for static analysis"
    fi
}

# ─── Android SDK Helpers ──────────────────────────────────────────────────────

# Returns ANDROID_HOME, respecting existing env var
get_android_home() {
    if [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME" ]]; then
        echo "$ANDROID_HOME"
    else
        echo "$HOME/android_sdk"
    fi
}

# ─── Emulator Reliability Functions ───────────────────────────────────────────

EMULATOR_PID=""
CLEANUP_FILES=()

# Register a file for cleanup on exit
register_cleanup() {
    CLEANUP_FILES+=("$1")
}

# Cleanup handler — kills emulator and removes registered temp files
cleanup() {
    kill_emulator 2>/dev/null || true
    for f in "${CLEANUP_FILES[@]}"; do
        rm -f "$f" 2>/dev/null || true
    done
}

# Wait for Android system to fully boot.
# Usage: wait_for_boot [timeout_seconds]  (default: 120)
wait_for_boot() {
    local timeout="${1:-120}"
    local elapsed=0
    local interval=3

    log_info "Waiting for device to fully boot (timeout: ${timeout}s)..."
    # First wait for adb to see the device at all
    adb wait-for-device 2>/dev/null

    while (( elapsed < timeout )); do
        local boot_status
        boot_status=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)
        if [[ "$boot_status" == "1" ]]; then
            log_ok "Device booted (${elapsed}s)"
            return 0
        fi

        # Check emulator process is still alive
        if [[ -n "$EMULATOR_PID" ]] && ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
            log_warn "Emulator process (PID $EMULATOR_PID) died"
            return 1
        fi

        sleep "$interval"
        (( elapsed += interval ))
    done

    log_warn "Boot timeout after ${timeout}s"
    return 1
}

# Start an emulator and wait for full boot.
# Usage: start_emulator AVD_NAME [extra_flags...]
# Example: start_emulator A10 -writable-system
start_emulator() {
    local avd_name="$1"
    shift
    local extra_flags=("$@")

    log_info "Starting emulator: $avd_name ${extra_flags[*]:-}"
    emulator -avd "$avd_name" "${extra_flags[@]}" >/dev/null 2>&1 &
    EMULATOR_PID=$!

    # Give the process a moment to fail immediately (bad AVD name, etc.)
    sleep 2
    if ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
        log_warn "Emulator failed to start (PID $EMULATOR_PID exited immediately)"
        return 1
    fi

    if ! wait_for_boot 120; then
        log_warn "Emulator failed to boot"
        return 1
    fi
    return 0
}

# Kill the tracked emulator process
kill_emulator() {
    if [[ -n "$EMULATOR_PID" ]] && kill -0 "$EMULATOR_PID" 2>/dev/null; then
        log_info "Killing emulator (PID $EMULATOR_PID)..."
        kill "$EMULATOR_PID" 2>/dev/null || true
        # Wait for it to actually die
        local waited=0
        while kill -0 "$EMULATOR_PID" 2>/dev/null && (( waited < 10 )); do
            sleep 1
            (( waited++ ))
        done
        if kill -0 "$EMULATOR_PID" 2>/dev/null; then
            kill -9 "$EMULATOR_PID" 2>/dev/null || true
        fi
        EMULATOR_PID=""
    else
        # Fallback: kill any emulator process
        pkill -f "emulator.*-avd" 2>/dev/null || true
    fi
}

# Run adb root and wait for device to come back (adbd restarts).
# Retries up to 3 times.
adb_root_and_wait() {
    local max_retries=3
    local attempt=1

    while (( attempt <= max_retries )); do
        log_info "Running adb root (attempt $attempt/$max_retries)..."
        adb root 2>/dev/null || true
        sleep 3

        # After adb root, adbd restarts — wait for device to be reachable
        if wait_for_boot 60; then
            log_ok "Device is rooted and ready"
            return 0
        fi

        log_warn "adb root attempt $attempt failed, retrying..."
        (( attempt++ ))
    done

    log_warn "adb root failed after $max_retries attempts"
    return 1
}


# ─── Proxy Configuration ─────────────────────────────────────────────────────

# Configure the emulator's global HTTP proxy to point at Burp Suite on the host.
# Usage: configure_proxy [port]  (default: 8080)
# Note: 10.0.2.2 is Android emulator's alias for host 127.0.0.1
configure_proxy() {
    local port="${1:-${BURP_PORT:-8080}}"
    local host="10.0.2.2"

    log_info "Configuring proxy: ${host}:${port}"
    adb shell settings put global http_proxy "${host}:${port}" 2>/dev/null || {
        log_warn "Failed to set proxy via settings"
        return 1
    }

    # Verify
    local current_proxy
    current_proxy=$(adb shell settings get global http_proxy 2>/dev/null | tr -d '\r\n')
    if [[ "$current_proxy" == "${host}:${port}" ]]; then
        log_ok "Proxy configured: ${host}:${port}"
        return 0
    else
        log_warn "Proxy verification failed (got: '${current_proxy:-empty}')"
        return 1
    fi
}
