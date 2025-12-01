#!/bin/bash

set -euo pipefail

PlatformToolsL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
CmdlineTools="https://developer.android.com/studio#cmdline-tools"
MagiskRepoAPI="https://api.github.com/repos/topjohnwu/Magisk/releases/latest"

main() {
    echo "[*] Starting Tools downloader"
    # download platform tools

    local PlatformToolsOutput="$PWD/platform-tools.zip"
    if [[ -f "$PlatformToolsOutput" ]]; then
        echo "[*] Platform tools already downloaded skippin it"
    else
        if ! curl -fsSL "$PlatformToolsL" -o "$PlatformToolsOutput"; then
            echo "[!] Failed to download Platform tools"
            rm -f "$PlatformToolsOutput"
            return 1
        fi
        echo "[✓] Platform tools downloaded successfully"
    fi

    # download cmdline tools

    local CmdlineToolsOutput="$PWD/cmdline-tools.zip"
    if [[ -f "$CmdlineToolsOutput" ]]; then
        echo "[*] Cmdline tools already downloaded skippin it"
    else 
        local url
        url=$(curl -fsSL "$CmdlineTools" | \
          grep -oP 'https://dl.google.com/android/repository/commandlinetools-linux-[0-9]+_latest\.zip' | \
          head -n 1)
    
        if [[ -z "$url" ]]; then
            echo "[!] Failed to extract cmdline-tools URL"
            return 1
        else
            if ! curl -fsSL "$url" -o "$CmdlineToolsOutput"; then
                echo "[!] Failed to download cmdline-tools"
                rm -f "$CmdlineToolsOutput"
                return 1
            fi
        fi
        echo "[✓] Cmdline tools downloaded successfully"
    fi
    

    # download magisk

    local MagiskOutput="$PWD/Magisk.zip"
    if [[ -f "$MagiskOutput" ]]; then
        echo "[*] Magisk already downloaded skippin it"
    else
        local release_json
        release_json=$(curl -fsSL "$MagiskRepoAPI")
    
        local apk_url
        apk_url=$(echo "$release_json" | \
                  grep -oP '"browser_download_url":\s*"\K[^"]+Magisk-v[^"]+\.apk' | \
                  head -n 1)
    
        if [[ -z "$apk_url" ]]; then
            echo "[!] Failed to extract Magisk APK URL"
            return 1
        fi
    
        local version
        version=$(echo "$apk_url" | grep -oP 'Magisk-v\K[0-9.]+')
        echo "[✓] Found Magisk version: ${version:-latest}"
    
        if ! curl -fsSL "$apk_url" -o "$MagiskOutput"; then
            echo "[!] Failed to download Magisk"
            rm -f "$MagiskOutput"
            return 1
        fi
        echo "[✓] Magisk downloaded successfully"
    fi
}
main "$@"
main "$@"