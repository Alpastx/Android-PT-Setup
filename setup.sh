#!/bin/bash

set -euo pipefail

# Check for burp certificate
if [[ ! -f "burp.der" ]]; then
    echo "[!] burp.der not found"
    echo "Please export Burp certificate as DER format and name it burp.der"
    exit 1
fi
echo "[✓] Found burp.der certificate"

echo "[*] Downloading Cmdlinetools, PlatformTools, Magisk"

bash Tools-downloader.sh || {
    echo "[!] Download failed"
    exit 1
}
echo "[*] Unzipping Cmdlinetools, PlatformTools, Magisk"

if [[ -f "platform-tools.zip" ]]; then
    unzip -q platform-tools.zip
else 
    echo "[!] platform-tools.zip not found"
    exit 1
fi

if [[ -f "cmdline-tools.zip" ]]; then
    unzip -q cmdline-tools.zip
else 
    echo "[!] cmdline-tools.zip not found"
    exit 1
fi
echo "[*] Organizing files"

mkdir -p android_sdk/cmdline-tools/latest
mkdir -p android_sdk/platforms
mv cmdline-tools/* android_sdk/cmdline-tools/latest/ 2>/dev/null || true
rm -rf cmdline-tools
mv platform-tools android_sdk/

# Cleanup zip files
rm -f platform-tools.zip cmdline-tools.zip

echo "[*] Cloning rootAVD into android_sdk"

if command -v git >/dev/null 2>&1; then
    git clone https://gitlab.com/newbit/rootAVD.git android_sdk/rootAVD 2</dev/null || true
else
    echo "[!] git is not installed. Please install git first."
    exit 1
fi

mv Magisk.zip android_sdk/rootAVD/Magisk.zip

mv android_sdk "$HOME/"

echo "[*] Setting up environment in .zshrc"

# Add Android SDK paths and aliases to .zshrc
cat >> "$HOME/.zshrc" << 'EOL'

# Android SDK Paths
export ANDROID_HOME=$HOME/android_sdk
export PATH="$HOME/android_sdk/cmdline-tools/latest/bin:$PATH"
export PATH="$HOME/android_sdk/platform-tools:$PATH"
export PATH="$HOME/android_sdk/emulator:$PATH"

# Android Emulator Aliases
alias A10='emulator -avd A10 -writable-system'
alias A14PR='emulator -avd A14PR'
EOL

echo "[*] Applying changes to current shell"
export ANDROID_HOME="$HOME/android_sdk"
export PATH="$HOME/android_sdk/cmdline-tools/latest/bin:$PATH"
export PATH="$HOME/android_sdk/platform-tools:$PATH"
export PATH="$HOME/android_sdk/emulator:$PATH"

echo "[*] Installing required packages"

if command -v yay >/dev/null 2>&1; then
    yay -S --noconfirm jdk python-pipx
else
    echo "[!] yay not found. Please install yay first."
    exit 1
fi

echo "[*] Installing Android system images"

sdkmanager --install "system-images;android-29;google_apis;x86" 
sdkmanager --install "system-images;android-34;google_apis_playstore;x86_64" 

echo "[*] Creating Android Virtual Devices"

avdmanager create avd -n "A10" -k "system-images;android-29;google_apis;x86" --force
avdmanager create avd -n "A14PR" -k "system-images;android-34;google_apis_playstore;x86_64" --force

echo "[*] Setting up Android configuration"

ln -sf "$HOME/.config/.android" "$HOME/.android"
echo "[*] Installing pentesting tools"

pipx install frida-tools
pipx install objection
pipx install apkleaks

echo "[*] Configuring hardware keys for AVDs"

bash HWKeys.sh A10
bash HWKeys.sh A14PR


echo "[*] Setting up A10 with Burp certificate"

# Check for burp certificate
    if [[ ! -f "burp.der" ]]; then
        echo "[!] burp.der not found"
        echo "Please export Burp certificate as DER format and name it burp.der"
        return 1
    else
        echo "[✓] Found burp.der certificate"
        bash rootAVD.sh A10 
    fi



sleep 10

echo "[*] Rooting A14PR with Magisk"

bash rootAVD.sh A14PR || {
    echo "[!] A14PR setup failed"
    exit 1
}

echo "[✓] Setup completed successfully!"
echo ""
echo "You can now use:"
echo "  A10   - Launch Android 10 emulator with writable system"
echo "  A14PR - Launch Android 14 emulator"
