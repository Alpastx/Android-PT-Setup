#!/bin/bash

echo -e "\n[*] Downloading Cmdlinetools, PlatformTools, Magisk\n"

bash Tools-downloader.sh || {
    echo "[!] Download failed"
    exit 1
}
 
echo -e "\n[*] Unzipping Cmdlinetools, PlatformTools, Magisk\n"

# Check for platform tools
if [ -f "platformtools.zip" ]; then
    unzip -q platformtools.zip
else 
    echo "Platform tools zip not found"
    exit 1
fi

if [ -n "cmdlinetools.zip" ]; then
    unzip -q cmdlinetools.zip
else 
    echo "Command-line tools zip not found"
    exit 1
fi

echo -e "\n[*] Organizing files\n"

mkdir -p android_sdk/cmdline-tools/latest
mkdir -p android_sdk/platforms
mv cmdline-tools/* android_sdk/cmdline-tools/latest/ 2>/dev/null
rm -rf cmdline-tools
mv platform-tools android_sdk/

# Cleanup zip files
rm -f platformtools.zip cmdlinetools.zip

echo -e "\n[*] git cloning rootAVD in android_sdk\n"

if command -v git > /dev/null 2>&1; then
    git clone https://gitlab.com/newbit/rootAVD.git android_sdk/rootAVD
else
    echo -e "\n[*] install git pls.\n"
fi

mv Magisk.zip android_sdk/rootAVD/Magisk.zip

mv android_sdk $HOME/

echo -e "\n[*] Setting up environment in .zshrc\n"

# Add Android SDK paths and aliases to .zshrc
cat >> ~/.zshrc << 'EOL'

# Android SDK Paths
export ANDROID_HOME=$HOME/android_sdk
export PATH="$HOME/android_sdk/cmdline-tools/latest/bin:$PATH"
export PATH="$HOME/android_sdk/platform-tools:$PATH"
export PATH="$HOME/android_sdk/emulator:$PATH"

# Android Emulator Aliases
alias A10='emulator -avd A10 -writable-system'
alias A14PR='emulator -avd A14PR'
EOL

echo -e "\n[*] Applying changes to .zshrc\n"
source $HOME/.zshrc

# Install required packages
echo -e "\n[*] Installing required packages\n"
if command -v yay > /dev/null 2>&1; then
    yay -S --noconfirm jdk python-pipx
else
    echo -e "\n[!] pls install yay\n"
    exit 1
fi


echo -e "\n[*] Installing Android system images\n"
sdkmanager --install "system-images;android-29;google_apis;x86" 
sdkmanager --install "system-images;android-34;google_apis_playstore;x86_64" 

echo -e "\n[*] Creating Android Virtual Devices\n"
avdmanager create avd -n "A10" -k "system-images;android-29;google_apis;x86" --force
avdmanager create avd -n "A14PR" -k "system-images;android-34;google_apis_playstore;x86_64" --force

echo -e "\n[*] Setting up Android configuration\n"
ln -sf $HOME/.config/.android $HOME/.android

echo -e "\n[*] Installing pentesting tools\n"
pipx install frida-tools
pipx install objection
pipx install frida
pipx install apkleaks

echo -e "\n[*] Configuring hardware keys for AVDs\n"
bash HWKeys.sh A10
bash HWKeys.sh A14PR

echo -e "\n[✓] Setup completed successfully!\n"
echo -e "You can now use:"
echo -e "  A10   - Launch Android 10 emulator with writable system"
echo -e "  A14PR - Launch Android 14 emulator\n"

bash rootAVD.sh A10 || {
    echo "[!] execution failed"
    exit 1
}
