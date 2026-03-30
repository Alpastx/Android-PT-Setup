# Android PT Setup

Automated Android penetration testing environment for Linux.

## Supported Platforms

- **Arch Linux** (yay / pacman)
- **Ubuntu / Debian** (apt)
- **Fedora** (dnf)

## Requirements

- Linux (see supported platforms above)
- 20GB+ free disk space
- `burp.der` (Burp certificate in DER format)

## Install

```bash
git clone https://github.com/Alpastx/Android-PT-Setup.git
cd Android-PT-Setup
bash setup.sh
```

## Verify

```bash
bash verify.sh          # Static checks (tools, files, config)
bash verify.sh --live   # Full check (starts emulators, validates root, certs, proxy)
```

## Uninstall

```bash
bash uninstall.sh
```

## Usage

```bash
A10      # Launch Android 10 (rooted + Burp cert + proxy)
A14PR    # Launch Android 14 (Magisk + Burp cert + proxy)

# Start frida-server on device
adb shell "/data/local/tmp/frida-server &"

# Use bypass scripts
frida -U -f com.example.app -l ~/android_sdk/scripts/ssl-bypass-universal.js
```

## What Gets Installed

- Android SDK (platform-tools, cmdline-tools, emulator)
- AVDs: A10 (API 29), A14PR (API 34) — both rooted with Burp cert and proxy configured
- Dynamic tools: frida-tools + frida-server (on device), objection
- Static tools: apkleaks, jadx, apktool
- Magisk + rootAVD + MagiskTrustUserCerts
- Frida scripts: SSL bypass, OkHttp bypass, root detection bypass

## Scripts

| Script | Description |
|--------|-------------|
| `setup.sh` | Full installation |
| `verify.sh` | Post-setup health check |
| `uninstall.sh` | Remove everything |
| `rootAVD.sh <AVD>` | Root AVD / install certs / push frida-server |
| `HWKeys.sh <AVD>` | Enable hardware keyboard |
| `Tools-downloader.sh` | Download SDK + Magisk + modules |
| `lib.sh` | Shared utility library |

## Frida Scripts

Located in `~/android_sdk/scripts/` after setup:

| Script | Purpose |
|--------|---------|
| `ssl-bypass-universal.js` | Bypass TrustManager, OkHttp, Conscrypt, WebView |
| `ssl-bypass-okhttp.js` | Targeted OkHttp v2/v3/v4 bypass |
| `root-detection-bypass.js` | Hide su, Magisk, Build.TAGS, native checks |

## SSL Interception

1. Export Burp cert as `burp.der`
2. Place in project directory before running `setup.sh`
3. Certificate installs automatically on both A10 and A14PR
4. Proxy auto-configured to `10.0.2.2:8080` (host loopback)
5. Override port: `BURP_PORT=9090 bash setup.sh`

## File Locations

```
~/android_sdk/              # SDK and tools
~/android_sdk/scripts/      # Frida bypass scripts
~/android_sdk/rootAVD/      # rootAVD + Magisk
~/.android/avd/             # AVD configs
```

## How It Works

### A10 (Android 10)
- Uses `google_apis` image (no Play Store, easier to root)
- Runs with `-writable-system` flag for system modifications
- Burp certificate installed directly to `/system/etc/security/cacerts/`
- AVB (Android Verified Boot) disabled for persistence
- Proxy and frida-server auto-configured

### A14PR (Android 14)
- Uses `google_apis_playstore` image (includes Play Store)
- Rooted via Magisk using [rootAVD](https://gitlab.com/newbit/rootAVD)
- Burp cert via MagiskTrustUserCerts module (user cert promoted to system)
- System remains unmodified (systemless root)
- Proxy and frida-server auto-configured

### Tools Installed

| Tool | Purpose |
|------|---------|
| **frida-tools** | Dynamic instrumentation for app analysis |
| **frida-server** | Server component pushed to emulators |
| **objection** | Runtime mobile exploration using Frida |
| **apkleaks** | Scan APKs for URIs, endpoints, and secrets |
| **jadx** | Java decompiler for APK reverse engineering |
| **apktool** | APK unpacker and repacker |
| **adb** | Android Debug Bridge for device communication |
| **Magisk** | Systemless root and module framework |

### Environment Variables

Added to your shell RC file (`~/.zshrc` or `~/.bashrc`):
```bash
export ANDROID_HOME=$HOME/android_sdk
export PATH="$HOME/android_sdk/cmdline-tools/latest/bin:$PATH"
export PATH="$HOME/android_sdk/platform-tools:$PATH"
export PATH="$HOME/android_sdk/emulator:$PATH"
```
