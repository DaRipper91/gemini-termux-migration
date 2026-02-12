# Gemini CLI Termux Migration

This repository provides scripts to migrate your local [Gemini CLI](https://github.com/DaRipper91/gemini-cli-termux) configuration and compatible extensions to a Termux environment on Android.

## Overview

The migration process involves two main steps:
1.  **Packaging:** Run `package_for_termux.sh` on your Linux host to create a compressed bundle of your `.gemini` folder, excluding incompatible extensions like `ComputerUse`.
2.  **Installation:** Run the generated `install.sh` inside Termux on your Android device to set up dependencies, fix configuration paths, and install extension-specific requirements.

## How to Use

### 1. On your Linux Host

Clone this repository or download the script:

```bash
git clone https://github.com/DaRipper91/gemini-termux-migration.git
cd gemini-termux-migration
chmod +x package_for_termux.sh
./package_for_termux.sh
```

This will create `gemini-termux-bundle.tar.gz` in your home directory.

### 2. Transfer the Bundle

Transfer `gemini-termux-bundle.tar.gz` to your Android device (e.g., via `adb push`, cloud storage, or USB).

### 3. On your Android Device (Termux)

Open Termux and run:

```bash
# Extract the bundle
mkdir -p temp_gemini
tar -xzf gemini-termux-bundle.tar.gz -C temp_gemini

# Run the installer
cd temp_gemini
chmod +x install.sh
./install.sh
```

## Features

- **Automated Dependency Check:** Installs `nodejs`, `python`, `git`, and other necessary binaries in Termux.
- **Path Reconfiguration:** Automatically replaces host-specific absolute paths (e.g., `/home/username`) with the Termux-native `$HOME` path.
- **Extension Filtering:** Safely skips GUI-heavy extensions (like `ComputerUse`) that are not compatible with Termux's environment.
- **Node/Python Setup:** Automatically runs `npm install` and `pip install` for bundled extensions.

## License

MIT
