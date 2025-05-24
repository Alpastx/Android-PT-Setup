#!/bin/bash

# Check if AVD name is provided
if [ $# -eq 0 ]; then
    echo -e "\n[!] Please provide AVD name as argument"
    echo -e "Usage: $0 <avd_name>\n"
    echo "Available AVDs:"
    avdmanager list avd | grep "Name:" | cut -d ":" -f 2
    exit 1
fi

AVD_NAME=$1

function A10() {
    echo -e "\n[*] Setting up Android 10 AVD with Burp certificate\n"
    
    # Check for burp certificate
    if [ ! -f "burp.der" ]; then
        echo "[!] burp.der not found"
        echo "Please export Burp certificate as DER format and name it burp.der"
        exit 1
    fi
    echo "[✓] Found burp.der certificate"

    # Check and install OpenSSL if needed
    if ! command -v openssl >/dev/null 2>&1; then
        echo "[*] OpenSSL not found, installing..."
        if ! command -v yay >/dev/null 2>&1; then
            echo "[!] yay not found. Please install yay first"
            exit 1
        fi
        yay -S --noconfirm openssl || {
            echo "[!] Failed to install OpenSSL"
            exit 1
        }
    fi
    echo "[✓] OpenSSL is installed"

    # Generate certificate files
    echo "[*] Converting certificate to Android format..."
    openssl x509 -inform der -in burp.der -out burp.cer > /dev/null 2>&1 || {
        echo "[!] Failed to convert certificate"
        exit 1
    }

    # Generate hash and prepare certificate
    hash=$(openssl x509 -inform PEM -subject_hash_old -in burp.cer | head -1)
    cp burp.cer "$hash.0"
    echo "[✓] Certificate prepared: $hash.0"

    # Start emulator
    echo "[*] Starting Android 10 emulator..."
    emulator -avd A10 -writable-system > /dev/null 2>&1 &
    
    # Wait for device to be ready
    echo "[*] Waiting for emulator to start..."
    adb wait-for-device
    sleep 10

    # First root cycle
    echo "[*] Preparing system for certificate installation..."
    adb root
    sleep 5
    adb shell avbctl disable-verification
    adb reboot
    
    # Wait for reboot
    echo "[*] Waiting for device to reboot..."
    adb wait-for-device
    sleep 10

    # Second root cycle and certificate installation
    echo "[*] Installing certificate..."
    adb root
    sleep 5
    adb remount
    adb push "$hash.0" /system/etc/security/cacerts/ || {
        echo "[!] Failed to push certificate"
        exit 1
    }
    adb shell chmod 644 /system/etc/security/cacerts/"$hash.0"

    # Final reboot
    echo "[*] Applying changes..."
    adb reboot
    sleep 20

    # Cleanup
    echo "[*] Cleaning up..."
    pkill -f "emulator.*-avd"
    rm -f burp.cer "$hash.0"

    echo "[✓] Android 10 AVD setup completed successfully"
}

# Function to root Android 14
function A14PR() {
    echo -e "\n[*] Setting up Android 14 AVD\n"
    cd $HOME/android_sdk/rootAVD || {
        echo "[!] rootAVD directory not found"
        exit 1
    }
    ./rootAVD.sh "$AVD_NAME" Magisk.zip
}

# Check AVD name and call appropriate function
case "$AVD_NAME" in
    "A10")
        A10
        ;;
    "A14PR")
        A14PR
        ;;
    *)
        echo -e "\n[!] Unknown AVD name: $AVD_NAME"
        echo "Available AVDs:"
        avdmanager list avd | grep "Name:" | cut -d ":" -f 2
        exit 1
        ;;
esac

echo -e "\n[✓] Setup completed for $AVD_NAME\n"

# work on A14 Rooting 
# emulator -avd A14PR > /dev/null 2>&1 &

# sleep 30

# echo -e "Rooting A14 Emulator...\n"

# $HOME/android_sdk/rootAVD/rootAVD.sh $HOME/android_sdk/system-images/android-34/google_apis_playstore/x86_64/ramdisk.img