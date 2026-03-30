#!/bin/bash
# lib.sh — Shared utility library for Android-PT-Setup
# Source this file in all scripts: source "$(dirname "$0")/lib.sh"

# ─── Logging ───────────────────────────────────────────────────────────────────

log_info()  { echo "[*] $*"; }
log_ok()    { echo "[✓] $*"; }
log_warn()  { echo "[!] $*" >&2; }
log_fatal() { echo "[!] $*" >&2; exit 1; }

# ─── OS / Distro Detection ────────────────────────────────────────────────────

detect_distro() {
    if [[ ! -f /etc/os-release ]]; then
        echo "unknown"
        return
    fi
    local id
    id=$(. /etc/os-release && echo "${ID:-unknown}")
    case "$id" in
        arch|endeavouros|manjaro) echo "arch" ;;
        debian|raspbian)          echo "debian" ;;
        ubuntu|linuxmint|pop)     echo "ubuntu" ;;
        fedora)                   echo "fedora" ;;
        *)                        echo "unknown" ;;
    esac
}

# ─── Package Manager ──────────────────────────────────────────────────────────

# Maps generic package names to distro-specific names and installs them.
# Usage: pkg_install jdk pipx openssl git unzip
pkg_install() {
    local distro
    distro=$(detect_distro)

    local -a resolved=()
    for pkg in "$@"; do
        case "$pkg" in
            jdk)
                case "$distro" in
                    arch)           resolved+=("jdk") ;;
                    debian|ubuntu)  resolved+=("openjdk-17-jdk") ;;
                    fedora)         resolved+=("java-17-openjdk") ;;
                    *)              log_fatal "Cannot resolve package '$pkg' for distro '$distro'" ;;
                esac ;;
            pipx)
                case "$distro" in
                    arch)           resolved+=("python-pipx") ;;
                    debian|ubuntu)  resolved+=("pipx") ;;
                    fedora)         resolved+=("pipx") ;;
                    *)              log_fatal "Cannot resolve package '$pkg' for distro '$distro'" ;;
                esac ;;
            jadx)
                case "$distro" in
                    arch)           resolved+=("jadx") ;;
                    debian|ubuntu)  resolved+=("jadx") ;;
                    fedora)         resolved+=("jadx") ;;
                    *)              log_warn "Cannot resolve package '$pkg' for distro '$distro' — install manually"; continue ;;
                esac ;;
            apktool)
                case "$distro" in
                    arch)           resolved+=("apktool") ;;
                    debian|ubuntu)  resolved+=("apktool") ;;
                    fedora)         resolved+=("apktool") ;;
                    *)              log_warn "Cannot resolve package '$pkg' for distro '$distro' — install manually"; continue ;;
                esac ;;
            openssl|git|unzip|curl)
                resolved+=("$pkg") ;;
            *)
                resolved+=("$pkg") ;;
        esac
    done

    log_info "Installing packages: ${resolved[*]}"
    case "$distro" in
        arch)
            if command -v yay >/dev/null 2>&1; then
                yay -S --noconfirm --needed "${resolved[@]}" || log_fatal "Package installation failed (yay)"
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm --needed "${resolved[@]}" || log_fatal "Package installation failed (pacman)"
            else
                log_fatal "No supported package manager found (need yay or pacman)"
            fi ;;
        debian|ubuntu)
            sudo apt-get update -qq || log_fatal "apt-get update failed"
            sudo apt-get install -y "${resolved[@]}" || log_fatal "Package installation failed (apt)"
            ;;
        fedora)
            sudo dnf install -y "${resolved[@]}" || log_fatal "Package installation failed (dnf)"
            ;;
        *)
            log_fatal "Unsupported distro '$distro'. Please install manually: ${resolved[*]}"
            ;;
    esac
    log_ok "Packages installed"
}

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

# ─── Frida Server Management ─────────────────────────────────────────────────

# Download and push frida-server to the connected emulator.
# Requires: adb connected, device rooted, frida-tools installed on host.
install_frida_server() {
    log_info "Installing frida-server on device..."

    # Get frida version from host tools (client/server MUST match)
    local frida_version
    frida_version=$(frida --version 2>/dev/null) || {
        log_warn "frida not found on host — skipping frida-server install"
        return 1
    }

    # Detect device architecture
    local device_arch
    device_arch=$(adb shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r\n')
    if [[ -z "$device_arch" ]]; then
        log_warn "Could not detect device architecture"
        return 1
    fi

    log_info "Frida version: $frida_version, device arch: $device_arch"

    local download_name="frida-server-${frida_version}-android-${device_arch}.xz"
    local download_url="https://github.com/frida/frida/releases/download/${frida_version}/${download_name}"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Download frida-server
    log_info "Downloading frida-server from GitHub..."
    if ! curl -fsSL "$download_url" -o "$tmp_dir/$download_name"; then
        rm -rf "$tmp_dir"
        log_warn "Failed to download frida-server (version mismatch or network issue)"
        return 1
    fi

    # Extract
    xz -d "$tmp_dir/$download_name" || {
        rm -rf "$tmp_dir"
        log_warn "Failed to extract frida-server"
        return 1
    }

    local server_binary="$tmp_dir/frida-server-${frida_version}-android-${device_arch}"

    # Push to device
    adb push "$server_binary" /data/local/tmp/frida-server || {
        rm -rf "$tmp_dir"
        log_warn "Failed to push frida-server to device"
        return 1
    }

    adb shell chmod 755 /data/local/tmp/frida-server

    # Verify
    local remote_version
    remote_version=$(adb shell /data/local/tmp/frida-server --version 2>/dev/null | tr -d '\r\n' || true)
    rm -rf "$tmp_dir"

    if [[ "$remote_version" == "$frida_version" ]]; then
        log_ok "frida-server $frida_version installed on device"
        return 0
    else
        log_warn "frida-server verification failed (expected $frida_version, got '${remote_version:-nothing}')"
        return 1
    fi
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

# ─── Magisk Module Management ────────────────────────────────────────────────

# Install a Magisk module from a zip file on the device.
# Usage: install_magisk_module /sdcard/Module.zip
install_magisk_module() {
    local module_path="$1"

    log_info "Installing Magisk module: $module_path"
    local result
    result=$(adb shell su -c "magisk --install-module '$module_path'" 2>&1) || {
        log_warn "Magisk module installation failed: $result"
        return 1
    }
    log_ok "Magisk module installed"
    return 0
}

# Install Burp certificate on a Magisk-rooted device using MagiskTrustUserCerts.
# Requires: device rooted with Magisk, MagiskTrustUserCerts.zip available, burp.der available.
install_burp_cert_magisk() {
    local android_home
    android_home=$(get_android_home)
    local module_zip="$android_home/rootAVD/MagiskTrustUserCerts.zip"

    if [[ ! -f "$module_zip" ]]; then
        log_warn "MagiskTrustUserCerts.zip not found at $module_zip — skipping cert install"
        return 1
    fi

    if [[ ! -f "burp.der" ]]; then
        log_warn "burp.der not found — skipping A14PR cert install"
        return 1
    fi

    # Push and install the Magisk module
    log_info "Pushing MagiskTrustUserCerts module to device..."
    adb push "$module_zip" /sdcard/MagiskTrustUserCerts.zip || {
        log_warn "Failed to push module to device"
        return 1
    }
    install_magisk_module /sdcard/MagiskTrustUserCerts.zip || return 1

    # Convert and install burp cert as user certificate
    log_info "Installing Burp certificate as user cert..."
    local tmp_pem
    tmp_pem=$(mktemp)
    openssl x509 -inform der -in burp.der -out "$tmp_pem" 2>/dev/null || {
        rm -f "$tmp_pem"
        log_warn "Failed to convert burp.der"
        return 1
    }

    adb push "$tmp_pem" /sdcard/burp-cert.pem || {
        rm -f "$tmp_pem"
        log_warn "Failed to push certificate to device"
        return 1
    }
    rm -f "$tmp_pem"

    # Install user cert via su (direct copy to user cert store)
    adb shell su -c "mkdir -p /data/misc/user/0/cacerts-added" 2>/dev/null || true
    local hash
    hash=$(openssl x509 -inform der -in burp.der -out /dev/stdout 2>/dev/null | \
           openssl x509 -subject_hash_old 2>/dev/null | head -1 | tr -d '\r\n')

    if [[ -n "$hash" ]]; then
        adb push burp.der /sdcard/burp.der
        adb shell su -c "openssl x509 -inform der -in /sdcard/burp.der -out /data/misc/user/0/cacerts-added/${hash}.0" 2>/dev/null || {
            log_warn "Direct cert install failed — install manually via Settings after reboot"
        }
        adb shell su -c "chmod 644 /data/misc/user/0/cacerts-added/${hash}.0" 2>/dev/null || true
    fi

    log_ok "MagiskTrustUserCerts installed — cert will be promoted to system store on reboot"
    log_info "Rebooting to activate module..."
    adb reboot 2>/dev/null || true
    wait_for_boot 120 || log_warn "Device did not come back after reboot"
    return 0
}
