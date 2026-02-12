#!/bin/bash

# Configuration
GEMINI_HOME="$HOME/.gemini"
BUNDLE_DIR="$HOME/.gemini/tmp/termux_bundle"
OUTPUT_FILE="$HOME/gemini-termux-bundle.tar.gz"

echo "Creating Termux migration bundle..."

# Clean previous bundle
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/extensions"

# Copy configurations
echo "Copying configuration files..."
[ -f "$GEMINI_HOME/GEMINI.md" ] && cp "$GEMINI_HOME/GEMINI.md" "$BUNDLE_DIR/"
[ -f "$GEMINI_HOME/config.json" ] && cp "$GEMINI_HOME/config.json" "$BUNDLE_DIR/"
[ -f "$GEMINI_HOME/extensions/extension-enablement.json" ] && cp "$GEMINI_HOME/extensions/extension-enablement.json" "$BUNDLE_DIR/extensions/"

# Copy extensions (excluding incompatible ones and large deps)
echo "Copying extensions (excluding ComputerUse)..."
for ext in "$GEMINI_HOME/extensions"/*; do
    ext_name=$(basename "$ext")
    
    # Exclusion List
    if [[ "$ext_name" == "ComputerUse" ]]; then
        echo "Skipping incompatible extension: $ext_name"
        continue
    fi
    if [[ "$ext_name" == "extension-enablement.json" ]]; then
        continue
    fi

    # Create destination dir
    mkdir -p "$BUNDLE_DIR/extensions/$ext_name"
    
    # Copy files excluding .git, node_modules, __pycache__, and build artifacts
    # Using rsync for cleaner exclusion
    if command -v rsync &> /dev/null; then
        rsync -av --exclude='.git' --exclude='node_modules' --exclude='__pycache__' --exclude='dist' --exclude='build' "$ext/" "$BUNDLE_DIR/extensions/$ext_name/" > /dev/null
    else
        # Fallback to cp if rsync is missing (less efficient exclusion)
        cp -r "$ext"/* "$BUNDLE_DIR/extensions/$ext_name/" 2>/dev/null
        rm -rf "$BUNDLE_DIR/extensions/$ext_name/.git"
        rm -rf "$BUNDLE_DIR/extensions/$ext_name/node_modules"
        rm -rf "$BUNDLE_DIR/extensions/$ext_name/__pycache__"
        rm -rf "$BUNDLE_DIR/extensions/$ext_name/dist"
        rm -rf "$BUNDLE_DIR/extensions/$ext_name/build"
    fi
done

# Modify extension-enablement.json to remove incompatible extensions
if [ -f "$BUNDLE_DIR/extensions/extension-enablement.json" ]; then
    echo "Updating extension-enablement.json..."
    # Use jq if available, otherwise simple sed/grep (risky for JSON but sufficient for simple removal)
    if command -v jq &> /dev/null; then
        jq 'del(.["ComputerUse"]) | del(.["adb-control-gemini"])' "$BUNDLE_DIR/extensions/extension-enablement.json" > "$BUNDLE_DIR/extensions/extension-enablement.json.tmp" && mv "$BUNDLE_DIR/extensions/extension-enablement.json.tmp" "$BUNDLE_DIR/extensions/extension-enablement.json"
    else
        # Basic removal via sed (assuming standard JSON formatting)
        sed -i '/"ComputerUse":/d' "$BUNDLE_DIR/extensions/extension-enablement.json"
        sed -i '/"adb-control-gemini":/d' "$BUNDLE_DIR/extensions/extension-enablement.json"
        # Fix potential trailing comma issues (simple approach)
        sed -i ':a;N;$!ba;s/,\s*}/}/g' "$BUNDLE_DIR/extensions/extension-enablement.json"
    fi
fi

# Create installation script INSIDE the bundle
cat > "$BUNDLE_DIR/install.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Termux Installation Script
# This script should be run on the Android device inside Termux.

GEMINI_HOME="$HOME/.gemini"

echo "Setting up Gemini environment in Termux..."

# 1. Install Dependencies
echo "Installing system packages..."
pkg update -y
pkg install -y git nodejs-lts python vim tmux android-tools build-essential binutils
# Check for tur-repo and opencv (optional but helpful)
# pkg install -y tur-repo && pkg install -y python-opencv || echo "OpenCV setup skipped (manual install may be needed)"

# 2. Setup Directory
mkdir -p "$GEMINI_HOME/extensions"

# 3. Copy Files
echo "Installing configuration and extensions..."
cp GEMINI.md "$GEMINI_HOME/" 2>/dev/null
cp config.json "$GEMINI_HOME/" 2>/dev/null
cp extensions/extension-enablement.json "$GEMINI_HOME/extensions/" 2>/dev/null

# Copy extensions recursively
cp -r extensions/* "$GEMINI_HOME/extensions/"

# 4. Fix Paths
echo "Updating configuration paths..."
# Replace /home/daripper with $HOME in all relevant config files
find "$GEMINI_HOME" -type f \( -name "*.json" -o -name "*.md" -o -name "*.toml" \) -exec sed -i "s|/home/daripper|$HOME|g" {} +

# 5. Install Extension Dependencies
echo "Installing extension dependencies..."
cd "$GEMINI_HOME/extensions" || exit 1

for dir in */; do
    [ -d "$dir" ] || continue
    ext_name=$(basename "$dir")
    echo " -> Setting up $ext_name..."
    cd "$dir" || continue

    if [ -f "package.json" ]; then
        echo "    Installing npm dependencies..."
        npm install --omit=dev --no-audit --no-fund
    fi

    if [ -f "requirements.txt" ]; then
        echo "    Installing pip dependencies..."
        pip install -r requirements.txt
    fi
    
    cd ..
done

echo "--------------------------------------------------"
echo "Setup complete! You can now use 'gemini' in Termux."
echo "Note: If 'gemini' command is not found, ensure the gemini-cli-termux package is installed."
EOF

chmod +x "$BUNDLE_DIR/install.sh"

# Archive the bundle
echo "Creating archive..."
cd "$BUNDLE_DIR" || exit 1
tar -czf "$OUTPUT_FILE" .

echo "--------------------------------------------------"
echo "✅ Bundle created at: $OUTPUT_FILE"
echo "To install on Termux:"
echo "1. Transfer '$OUTPUT_FILE' to your device (e.g., via 'adb push' or cloud)."
echo "2. Open Termux."
echo "3. Run: mkdir -p temp_gemini && tar -xzf gemini-termux-bundle.tar.gz -C temp_gemini"
echo "4. Run: cd temp_gemini && ./install.sh"
echo "--------------------------------------------------"
