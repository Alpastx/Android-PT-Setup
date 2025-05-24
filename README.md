# AndroidPT - Android Penetration Testing Automation Setup

This project provides an automated setup script for Android penetration testing environment on Linux systems. The script helps security researchers and penetration testers quickly set up their Android testing environment with essential tools and configurations.

## Features

- Automatic installation of required dependencies
- Setup of Android SDK and platform tools
- Installation of common Android pentesting tools:
  - ADB (Android Debug Bridge)
  - Frida
  - Jadx
  - Apktool
  - Drozer
  - MobSF
  - Burp Suite (Community Edition)
  - Genymotion
  - Scrcpy

## Prerequisites

- Linux-based operating system
- Internet connection
- Root/sudo privileges

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/AndroidPT.git
cd AndroidPT
```

2. Make the setup script executable:
```bash
chmod +x setup.sh
```

3. Run the setup script:
```bash
./setup.sh
```

## Post-Installation

After running the script, you'll need to:
1. Configure your Android device or emulator for testing
2. Set up Burp Suite certificate on your testing device
3. Configure proxy settings

## Tools Overview

- **ADB**: Android Debug Bridge for device communication
- **Frida**: Dynamic instrumentation toolkit
- **Jadx**: Dex to Java decompiler
- **Apktool**: Tool for reverse engineering Android APK files
- **Drozer**: Android security assessment framework
- **MobSF**: Mobile Security Framework
- **Burp Suite**: Web vulnerability scanner and proxy
- **Genymotion**: Android emulator
- **Scrcpy**: Display and control Android devices

## Troubleshooting

If you encounter any issues during installation:
1. Check your internet connection
2. Ensure you have sufficient disk space
3. Verify that all prerequisites are met
4. Check the logs in `setup.log`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This tool is for educational and ethical testing purposes only. Always obtain proper authorization before testing any applications or systems.