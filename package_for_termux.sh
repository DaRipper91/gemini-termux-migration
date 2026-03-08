#!/bin/bash

# Configuration
GEMINI_HOME="${GEMINI_HOME:-$HOME/.gemini}"
BUNDLE_DIR="${BUNDLE_DIR:-$GEMINI_HOME/tmp/termux_bundle}"
OUTPUT_FILE="${OUTPUT_FILE:-$HOME/gemini-termux-bundle.tar.gz}"

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

# Sanitize config.json (remove API Key)
if [ -f "$BUNDLE_DIR/config.json" ]; then
    echo "Sanitizing config.json (removing potential API keys)..."
    sed -i 's/"\([^"]*API_KEY[^"]*\)"[[:space:]]*:[[:space:]]*"[^"]*"/"\1": ""/Ig' "$BUNDLE_DIR/config.json"
    sed -i 's/"\([^"]*api_key[^"]*\)"[[:space:]]*:[[:space:]]*"[^"]*"/"\1": ""/Ig' "$BUNDLE_DIR/config.json"
    sed -i 's/"\([^"]*apiKey[^"]*\)"[[:space:]]*:[[:space:]]*"[^"]*"/"\1": ""/Ig' "$BUNDLE_DIR/config.json"
    # Replace values for keys matching *API_KEY*, *api_key*, or *apiKey*
    # We use sed to replace the value part.
    # Assuming "key": "value" format.
fi

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


# Create API setup script
cat > "$BUNDLE_DIR/set_api_key.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

CONFIG_FILE="$HOME/.gemini/config.json"

echo ""
echo "--------------------------------------------------"
echo "🔑 Gemini API Key Setup"
echo "--------------------------------------------------"
echo "To use Gemini CLI, you need to provide your API Key."
echo "If you don't have one, get it from: https://aistudio.google.com/app/apikey"
echo ""
echo -n "Paste your API Key here: "
read -r API_KEY

if [ -z "$API_KEY" ]; then
    echo "❌ API Key cannot be empty. Please run ./set_api_key.sh again."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found at $CONFIG_FILE"
    exit 1
fi

echo "Updating configuration..."

# Use jq if available for safe JSON manipulation
if command -v jq &> /dev/null; then
    if jq -e 'has("GEMINI_API_KEY")' "$CONFIG_FILE" >/dev/null; then
        jq --arg key "$API_KEY" '.GEMINI_API_KEY = $key' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ Updated GEMINI_API_KEY (via jq)"
    elif jq -e 'has("apiKey")' "$CONFIG_FILE" >/dev/null; then
        jq --arg key "$API_KEY" '.apiKey = $key' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ Updated apiKey (via jq)"
    else
        echo "⚠️  Could not find GEMINI_API_KEY or apiKey field in config.json."
    fi
# Fallback to python3
elif command -v python3 &> /dev/null; then
    API_KEY="$API_KEY" CONFIG_FILE="$CONFIG_FILE" python3 -c '
import json, os, sys
config_file = os.environ.get("CONFIG_FILE")
api_key = os.environ.get("API_KEY")
if not config_file or not api_key:
    sys.exit(1)
with open(config_file, "r") as f:
    data = json.load(f)
if "GEMINI_API_KEY" in data:
    data["GEMINI_API_KEY"] = api_key
    print("✅ Updated GEMINI_API_KEY (via python)")
elif "apiKey" in data:
    data["apiKey"] = api_key
    print("✅ Updated apiKey (via python)")
else:
    print("⚠️  Could not find GEMINI_API_KEY or apiKey field in config.json.")
    sys.exit(0)
with open(config_file + ".tmp", "w") as f:
    json.dump(data, f, indent=2)
os.replace(config_file + ".tmp", config_file)
'
# Last resort: sed with careful escaping
else
    echo "⚠️  Neither jq nor python3 found. Falling back to sed (less robust)..."
    # Escape for JSON and sed: 1. Backslashes 2. Double quotes 3. Ampersand (sed special char) 4. Pipe (sed delimiter)
    # We use | as sed delimiter
    API_KEY_ESC=$(echo "$API_KEY" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/&/\\\&/g' -e 's/|/\\|/g')
    if grep -q "GEMINI_API_KEY" "$CONFIG_FILE"; then
        sed -i "s|\"GEMINI_API_KEY\"[[:space:]]*:[[:space:]]*\".*\"|\"GEMINI_API_KEY\": \"$API_KEY_ESC\"|" "$CONFIG_FILE"
        echo "✅ Updated GEMINI_API_KEY (via sed)"
    elif grep -q "apiKey" "$CONFIG_FILE"; then
        sed -i "s|\"apiKey\"[[:space:]]*:[[:space:]]*\".*\"|\"apiKey\": \"$API_KEY_ESC\"|" "$CONFIG_FILE"
        echo "✅ Updated apiKey (via sed)"
    else
        echo "⚠️  Could not find GEMINI_API_KEY or apiKey field in config.json."
    fi
fi

echo "--------------------------------------------------"
EOF
chmod +x "$BUNDLE_DIR/set_api_key.sh"

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
pkg install -y git nodejs-lts python vim tmux android-tools build-essential binutils jq
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

# Prompt for API Key
if [ -f "./set_api_key.sh" ]; then
    ./set_api_key.sh
fi
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
