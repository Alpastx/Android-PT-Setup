#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/lib.sh"

PlatformToolsL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
CmdlineTools="https://developer.android.com/studio#cmdline-tools"
MagiskRepoAPI="https://api.github.com/repos/topjohnwu/Magisk/releases/latest"

main() {
    log_info "Starting Tools downloader"

    # download platform tools
    local PlatformToolsOutput="$PWD/platform-tools.zip"
    if [[ -f "$PlatformToolsOutput" ]]; then
        log_info "Platform tools already downloaded, skipping"
    else
        if ! curl -fsSL "$PlatformToolsL" -o "$PlatformToolsOutput"; then
            rm -f "$PlatformToolsOutput"
            log_fatal "Failed to download Platform tools"
        fi
        log_ok "Platform tools downloaded successfully"
    fi

    # download cmdline tools
    local CmdlineToolsOutput="$PWD/cmdline-tools.zip"
    if [[ -f "$CmdlineToolsOutput" ]]; then
        log_info "Cmdline tools already downloaded, skipping"
    else
        local url
        url=$(curl -fsSL "$CmdlineTools" | \
          grep -oP 'https://dl.google.com/android/repository/commandlinetools-linux-[0-9]+_latest\.zip' | \
          head -n 1)

        if [[ -z "$url" ]]; then
            log_fatal "Failed to extract cmdline-tools URL from developer.android.com"
        fi

        if ! curl -fsSL "$url" -o "$CmdlineToolsOutput"; then
            rm -f "$CmdlineToolsOutput"
            log_fatal "Failed to download cmdline-tools"
        fi
        log_ok "Cmdline tools downloaded successfully"
    fi

    # download magisk
    local MagiskOutput="$PWD/Magisk.zip"
    if [[ -f "$MagiskOutput" ]]; then
        log_info "Magisk already downloaded, skipping"
    else
        local release_json
        release_json=$(curl -fsSL "$MagiskRepoAPI") || log_fatal "Failed to fetch Magisk release info from GitHub API"

        local apk_url
        apk_url=$(echo "$release_json" | \
                  grep -oP '"browser_download_url":\s*"\K[^"]+Magisk-v[^"]+\.apk' | \
                  head -n 1)

        if [[ -z "$apk_url" ]]; then
            log_fatal "Failed to extract Magisk APK URL from GitHub release"
        fi

        local version
        version=$(echo "$apk_url" | grep -oP 'Magisk-v\K[0-9.]+')
        log_ok "Found Magisk version: ${version:-latest}"

        # rootAVD expects Magisk.zip (APK is a valid ZIP)
        if ! curl -fsSL "$apk_url" -o "$MagiskOutput"; then
            rm -f "$MagiskOutput"
            log_fatal "Failed to download Magisk"
        fi
        log_ok "Magisk downloaded successfully"
    fi
}

main "$@"
