# Android Penetration Testing Environment Setup

An automated setup for Android penetration testing environment on Linux, featuring pre-configured emulators with root access and SSL interception capabilities.

## Features

- Automated download and setup of Android SDK tools
- Pre-configured Android 10 and Android 14 emulators
- Automatic rooting with Magisk
- Burp Suite certificate integration
- Hardware keyboard support
- Writable system partition setup

## Prerequisites

- Linux-based operating system
- yay package manager (Arch Linux)
- Internet connection
- At least 20GB free disk space
- OpenSSL (auto-installed if missing)

## Quick Start

1. Clone this repository:
```bash
git clone https://github.com/yourusername/AndroidPT.git
cd AndroidPT
```

2. Run the setup script:
```bash
./setup.sh
```

## Available Scripts

### setup.sh
Main setup script that:
- Downloads Android SDK tools
- Sets up environment variables
- Creates and configures AVDs
- Installs necessary dependencies

### Tools-downloader.sh
Downloads required components:
- Android Platform Tools
- Android Command-line Tools
- Latest Magisk APK

### rootAVD.sh
Handles AVD rooting and Burp certificate installation:
```bash
./rootAVD.sh <avd_name>  # A10 or A14PR
```

### HWKeys.sh
Enables hardware keyboard support for AVDs:
```bash
./HWKeys.sh <avd_name>
```

## Emulator Configurations

### Android 10 (A10)
- API Level: 29
- Google APIs
- x86 architecture
- Writable system
- Root access
- Burp certificate pre-installed

### Android 14 (A14PR)
- API Level: 34
- Google Play Store
- x86_64 architecture
- Root access via Magisk

## Environment Setup

The scripts will automatically configure:
- ANDROID_HOME environment variable
- PATH additions for Android tools
- AVD configurations
- Burp Suite certificate integration

## Usage

### Starting Emulators
```bash
# Android 10 with writable system
A10

# Android 14 with Play Store
A14PR
```

### SSL Interception Setup
1. Export Burp certificate as 'burp.der'
2. Place in project directory
3. Run rootAVD.sh script
4. Certificate will be installed system-wide

### File Structure
```
$HOME/
├── android_sdk/
│   ├── cmdline-tools/
│   ├── platform-tools/
│   ├── rootAVD/
│   └── system-images/
└── .config/.android/
    └── avd/
```

## Included Tools

- adb (Android Debug Bridge)
- Frida
- Objection
- APKLeaks
- Magisk
- rootAVD

## Troubleshooting

### Common Issues

1. Emulator won't start
   - Check hardware virtualization support
   - Ensure KVM is properly configured

2. Root access issues
   - Verify Magisk installation
   - Check system partition is writable (A10)

3. Certificate problems
   - Ensure burp.der is in correct format
   - Verify certificate hash matches

