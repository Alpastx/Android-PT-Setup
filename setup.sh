#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/lib.sh"

# Check for burp certificate
if [[ ! -f "burp.der" ]]; then
    log_fatal "burp.der not found. Please export Burp certificate as DER format and name it burp.der"
fi
log_ok "Found burp.der certificate"

log_info "Downloading Cmdlinetools, PlatformTools, Magisk"

bash "$(dirname "$0")/Tools-downloader.sh" || log_fatal "Download failed"

log_info "Unzipping Cmdlinetools, PlatformTools"

if [[ -f "platform-tools.zip" ]]; then
    unzip -q platform-tools.zip || log_fatal "Failed to unzip platform-tools.zip"
else
    log_fatal "platform-tools.zip not found"
fi

if [[ -f "cmdline-tools.zip" ]]; then
    unzip -q cmdline-tools.zip || log_fatal "Failed to unzip cmdline-tools.zip"
else
    log_fatal "cmdline-tools.zip not found"
fi

log_info "Organizing files"

mkdir -p android_sdk/cmdline-tools/latest
mkdir -p android_sdk/platforms
mv cmdline-tools/* android_sdk/cmdline-tools/latest/ 2>/dev/null || log_fatal "Failed to move cmdline-tools"
rm -rf cmdline-tools
mv platform-tools android_sdk/ || log_fatal "Failed to move platform-tools"

# Cleanup zip files
rm -f platform-tools.zip cmdline-tools.zip

log_info "Cloning rootAVD into android_sdk"

if ! command -v git >/dev/null 2>&1; then
    pkg_install git
fi

if [[ -d "android_sdk/rootAVD" ]]; then
    log_info "rootAVD directory already exists, skipping clone"
else
    git clone https://gitlab.com/newbit/rootAVD.git android_sdk/rootAVD 2>/dev/null || \
        log_fatal "Failed to clone rootAVD repository"
fi

if [[ -f "Magisk.zip" ]]; then
    mv Magisk.zip android_sdk/rootAVD/Magisk.zip
else
    log_warn "Magisk.zip not found — A14PR rooting may fail"
fi

if [[ -f "MagiskTrustUserCerts.zip" ]]; then
    mv MagiskTrustUserCerts.zip android_sdk/rootAVD/MagiskTrustUserCerts.zip
else
    log_warn "MagiskTrustUserCerts.zip not found — A14PR cert install will be skipped"
fi

# Move SDK to home directory
local_android_home="$HOME/android_sdk"
if [[ -d "$local_android_home" ]]; then
    log_warn "$local_android_home already exists, merging files"
    cp -rn android_sdk/* "$local_android_home/" 2>/dev/null || true
    rm -rf android_sdk
else
    mv android_sdk "$HOME/"
fi

# Detect shell and configure environment
rc_file=$(detect_shell_rc)
log_info "Setting up environment in $rc_file"

if ! grep -q 'ANDROID_HOME' "$rc_file" 2>/dev/null; then
    cat >> "$rc_file" << 'EOL'

# Android SDK Paths
export ANDROID_HOME=$HOME/android_sdk
export PATH="$HOME/android_sdk/cmdline-tools/latest/bin:$PATH"
export PATH="$HOME/android_sdk/platform-tools:$PATH"
export PATH="$HOME/android_sdk/emulator:$PATH"

# Android Emulator Aliases
alias A10='emulator -avd A10 -writable-system'
alias A14PR='emulator -avd A14PR'
EOL
    log_ok "Environment configured in $rc_file"
else
    log_info "Android environment already in $rc_file, skipping"
fi

log_info "Applying changes to current shell"
export ANDROID_HOME="$HOME/android_sdk"
export PATH="$HOME/android_sdk/cmdline-tools/latest/bin:$PATH"
export PATH="$HOME/android_sdk/platform-tools:$PATH"
export PATH="$HOME/android_sdk/emulator:$PATH"

log_info "Installing required packages"
pkg_install jdk pipx

log_info "Installing Android system images"

sdkmanager --install "system-images;android-29;google_apis;x86" || \
    log_fatal "Failed to install Android 10 system image"
sdkmanager --install "system-images;android-34;google_apis_playstore;x86_64" || \
    log_fatal "Failed to install Android 14 system image"

log_info "Creating Android Virtual Devices"

avdmanager create avd -n "A10" -k "system-images;android-29;google_apis;x86" --force || \
    log_fatal "Failed to create A10 AVD"
avdmanager create avd -n "A14PR" -k "system-images;android-34;google_apis_playstore;x86_64" --force || \
    log_fatal "Failed to create A14PR AVD"

log_info "Setting up Android configuration"
mkdir -p "$HOME/.config/.android"
ln -sf "$HOME/.config/.android" "$HOME/.android"

log_info "Installing pentesting tools"

pipx install frida-tools || log_warn "frida-tools installation failed"
pipx install objection || log_warn "objection installation failed"
pipx install apkleaks || log_warn "apkleaks installation failed"

log_info "Installing static analysis tools"
pkg_install jadx apktool || log_warn "Some static analysis tools failed to install"

log_info "Configuring hardware keys for AVDs"

bash "$(dirname "$0")/HWKeys.sh" A10
bash "$(dirname "$0")/HWKeys.sh" A14PR

log_info "Setting up A10 with Burp certificate"

if [[ ! -f "burp.der" ]]; then
    log_fatal "burp.der not found. Please export Burp certificate as DER format and name it burp.der"
fi

log_ok "Found burp.der certificate"
bash "$(dirname "$0")/rootAVD.sh" A10 || log_fatal "A10 Burp certificate setup failed"

# Wait for A10 cleanup before starting A14PR
sleep 5
adb kill-server 2>/dev/null || true
sleep 3

log_info "Rooting A14PR with Magisk"

bash "$(dirname "$0")/rootAVD.sh" A14PR || log_fatal "A14PR Magisk setup failed"

# Copy Frida scripts to SDK directory
script_dir="$(dirname "$0")/scripts"
if [[ -d "$script_dir" ]]; then
    log_info "Copying Frida scripts to $ANDROID_HOME/scripts/"
    mkdir -p "$ANDROID_HOME/scripts"
    cp -r "$script_dir"/* "$ANDROID_HOME/scripts/" 2>/dev/null || true
    log_ok "Frida scripts installed"
fi

log_ok "Setup completed successfully!"
echo ""
echo "You can now use:"
echo "  A10   - Launch Android 10 emulator (rooted + Burp cert + proxy)"
echo "  A14PR - Launch Android 14 emulator (Magisk + Burp cert + proxy)"
echo ""
echo "Frida scripts available at: $ANDROID_HOME/scripts/"
echo "  frida -U -f com.example.app -l ~/android_sdk/scripts/ssl-bypass-universal.js"
echo ""
echo "Run: source $rc_file"
