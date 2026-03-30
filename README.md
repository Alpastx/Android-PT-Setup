# Android PT Setup

Automated Android penetration testing environment for Linux.

## Supported Platforms

- **Arch Linux** (yay / pacman)
- **Ubuntu / Debian** (apt)
- **Fedora** (dnf)

## Requirements

- Linux (see supported platforms above)
- **20GB+** free disk space
- **`burp.der`** — Burp certificate (DER format) in the project directory before `setup.sh`
- **Host tools (install yourself; not installed by this repo):** `git`, `pipx`, **OpenSSL** (`openssl` CLI); **`jadx`** is optional (recommended)
- `setup.sh` asks you to confirm `git` and `pipx` are installed, verifies them on `PATH`, and warns if `jadx` is missing
- Android SDK licenses are accepted non-interactively via `yes | sdkmanager --licenses` during setup
- Place **`burp.der`** next to `setup.sh` (or export **`BURP_DER`** when running `rootAVD.sh` alone); `setup.sh` always uses the repo directory, not your current working directory

## Install

```bash
git clone https://github.com/Alpastx/Android-PT-Setup.git
cd Android-PT-Setup
bash setup.sh
```

## Verify

```bash
bash verify.sh          # Static checks (see below)
bash verify.sh --live   # Also boots each AVD briefly (root, proxy on A10, Magisk hint on A14PR)
```

**Static checks:** `ANDROID_HOME` / `~/android_sdk`, host tools (`git`, `pipx`, `openssl`; `jadx` optional), SDK tools (`adb`, `sdkmanager`, `avdmanager`; `emulator` warns if missing), pipx tools (`frida`, `objection`, `apkleaks`, `pyapktool` or `apktool`), `burp.der` beside the repo scripts, AVDs and system images, `rootAVD` + `Magisk.zip`, shell RC entries (including `A14PR` alias). **Live checks:** `adb root` / `su` where applicable, optional frida-server on device, HTTP proxy **only for A10**, CA store sanity on A10, Magisk on A14PR.

## Uninstall

```bash
bash uninstall.sh
```

## Usage

```bash
A10      # Launch Android 10 (rooted + Burp cert + proxy)
A14PR    # Launch Android 14 (Magisk root)

# frida-server on the device is not installed by setup — download a build matching
# your host frida-tools version and push to /data/local/tmp/ when needed, then:
# adb shell "/data/local/tmp/frida-server &"
```

## What Gets Installed

- Android SDK (platform-tools, cmdline-tools; install **emulator** via `sdkmanager` if `emulator` is missing)
- AVDs: **A10** (API 29) — rooted, Burp CA in system store, HTTP proxy to host; **A14PR** (API 34) — Magisk via rootAVD
- **pipx:** frida-tools, objection, apkleaks, pyapktool

## Scripts

| Script | Description |
|--------|-------------|
| `setup.sh` | Full installation |
| `verify.sh` | Post-setup health check |
| `uninstall.sh` | Remove everything |
| `rootAVD.sh <AVD>` | A10 Burp/system CA + proxy; A14PR Magisk ramdisk patch |
| `HWKeys.sh <AVD>` | Enable hardware keyboard |
| `Tools-downloader.sh` | Download platform-tools, cmdline-tools, Magisk APK as zip |
| `lib.sh` | Shared utility library |

## SSL Interception

1. Export Burp cert as `burp.der`
2. Place in project directory before running `setup.sh`
3. **A10:** certificate is installed to the system CA store; proxy set to `10.0.2.2:8080` (override with `BURP_PORT`)
4. **A14PR:** Burp trust is not automated by this repo — configure manually if needed

## File Locations

```
~/android_sdk/              # SDK and tools
~/android_sdk/rootAVD/      # rootAVD + Magisk
~/.android/avd/             # AVD configs
```

## How It Works

### A10 (Android 10)

- `google_apis` image, `-writable-system`
- Burp certificate in `/system/etc/security/cacerts/`, AVB disabled for persistence
- HTTP proxy via `settings put global http_proxy`

### A14PR (Android 14)

- `google_apis_playstore` image
- Rooted with [rootAVD](https://gitlab.com/newbit/rootAVD) + Magisk (ramdisk patch)

### Tools (host)

| Tool | Purpose |
|------|---------|
| **frida-tools** | Dynamic instrumentation (install with pipx) |
| **objection** | Runtime exploration (pipx) |
| **apkleaks** | Scan APKs for secrets (pipx) |
| **pyapktool** | APK tooling (pipx) |
| **jadx** | Decompiler — install via distro package manager |
| **adb** | From platform-tools |

### Environment Variables

Added to your shell RC (`~/.zshrc` or `~/.bashrc`):

```bash
export ANDROID_HOME=$HOME/android_sdk
export PATH="$HOME/android_sdk/cmdline-tools/latest/bin:$PATH"
export PATH="$HOME/android_sdk/platform-tools:$PATH"
export PATH="$HOME/android_sdk/emulator:$PATH"
```
