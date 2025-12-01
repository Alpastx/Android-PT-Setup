# Android PT Setup

Automated Android penetration testing environment for Arch Linux.

## Requirements

- Arch Linux with `yay`
- 20GB+ free disk space
- `burp.der` (Burp certificate in DER format)

## Install

```bash
git clone https://github.com/yourusername/Android-PT-Setup.git
cd Android-PT-Setup
bash setup.sh
```

## Uninstall

```bash
bash uninstall.sh
```

## Usage

```bash
A10      # Launch Android 10 (rooted + Burp cert)
A14PR    # Launch Android 14 (rooted with Magisk)
```

## What Gets Installed

- Android SDK (platform-tools, cmdline-tools, emulator)
- AVDs: A10 (API 29), A14PR (API 34)
- Pentest tools: frida-tools, objection, apkleaks
- Magisk + rootAVD

## Scripts

| Script | Description |
|--------|-------------|
| `setup.sh` | Full installation |
| `uninstall.sh` | Remove everything |
| `rootAVD.sh <AVD>` | Root AVD / install Burp cert |
| `HWKeys.sh <AVD>` | Enable hardware keyboard |
| `Tools-downloader.sh` | Download SDK + Magisk |

## SSL Interception

1. Export Burp cert as `burp.der`
2. Place in project directory before running `setup.sh`
3. Certificate installs automatically on A10

## File Locations

```
~/android_sdk/          # SDK and tools
~/.android/avd/         # AVD configs
```

## How It Works

### A10 (Android 10)
- Uses `google_apis` image (no Play Store, easier to root)
- Runs with `-writable-system` flag for system modifications
- Burp certificate is installed directly to `/system/etc/security/cacerts/`
- AVB (Android Verified Boot) is disabled for persistence

### A14PR (Android 14)
- Uses `google_apis_playstore` image (includes Play Store)
- Rooted via Magisk using [rootAVD](https://gitlab.com/newbit/rootAVD)
- Magisk patches the ramdisk.img for root access
- System remains unmodified (systemless root)

### Tools Installed

| Tool | Purpose |
|------|---------|
| **frida-tools** | Dynamic instrumentation for app analysis |
| **objection** | Runtime mobile exploration using Frida |
| **apkleaks** | Scan APKs for URIs, endpoints, and secrets |
| **adb** | Android Debug Bridge for device communication |
| **Magisk** | Systemless root and module framework |

### Environment Variables

Added to `~/.zshrc`:
```bash
export ANDROID_HOME=$HOME/android_sdk
export PATH="$HOME/android_sdk/cmdline-tools/latest/bin:$PATH"
export PATH="$HOME/android_sdk/platform-tools:$PATH"
export PATH="$HOME/android_sdk/emulator:$PATH"
```
