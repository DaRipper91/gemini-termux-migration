#!/bin/bash

# Test script for package_for_termux.sh

set -e

# Setup temporary directories
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

MOCK_HOME="$TEST_DIR/home"
MOCK_GEMINI_HOME="$MOCK_HOME/.gemini"
MOCK_BUNDLE_DIR="$TEST_DIR/bundle"
MOCK_OUTPUT="$TEST_DIR/bundle.tar.gz"

mkdir -p "$MOCK_GEMINI_HOME/extensions/ComputerUse"
mkdir -p "$MOCK_GEMINI_HOME/extensions/ValidExtension/.git"
mkdir -p "$MOCK_GEMINI_HOME/extensions/ValidExtension/node_modules"
mkdir -p "$MOCK_GEMINI_HOME/extensions/ValidExtension/__pycache__"
mkdir -p "$MOCK_GEMINI_HOME/extensions/ValidExtension/dist"
mkdir -p "$MOCK_GEMINI_HOME/extensions/ValidExtension/build"

echo "Some file" > "$MOCK_GEMINI_HOME/extensions/ValidExtension/index.js"
echo "Some data" > "$MOCK_GEMINI_HOME/GEMINI.md"

cat > "$MOCK_GEMINI_HOME/config.json" <<EOF
{
  "GEMINI_API_KEY": "secret-key",
  "api_key": "another-secret",
  "apiKey": "third-secret",
  "other_config": "value"
}
EOF

cat > "$MOCK_GEMINI_HOME/extensions/extension-enablement.json" <<EOF
{
  "ComputerUse": true,
  "adb-control-gemini": true,
  "ValidExtension": true
}
EOF

echo "Running package_for_termux.sh..."
export GEMINI_HOME="$MOCK_GEMINI_HOME"
export BUNDLE_DIR="$MOCK_BUNDLE_DIR"
export OUTPUT_FILE="$MOCK_OUTPUT"

# Run the script (assume it is in the parent directory)
bash "$(dirname "$0")/../package_for_termux.sh"

echo "Verifying results..."

# 1. Verify ComputerUse is excluded from extensions
if [ -d "$MOCK_BUNDLE_DIR/extensions/ComputerUse" ]; then
    echo "FAILED: ComputerUse should be excluded from extensions directory"
    exit 1
fi

# 2. Verify ValidExtension is included
if [ ! -d "$MOCK_BUNDLE_DIR/extensions/ValidExtension" ]; then
    echo "FAILED: ValidExtension should be included"
    exit 1
fi

# 3. Verify excluded patterns are removed from ValidExtension
for pattern in .git node_modules __pycache__ dist build; do
    if [ -d "$MOCK_BUNDLE_DIR/extensions/ValidExtension/$pattern" ]; then
        echo "FAILED: $pattern should be excluded from ValidExtension"
        exit 1
    fi
done

# 4. Verify config.json sanitization
if grep -q "secret-key" "$MOCK_BUNDLE_DIR/config.json"; then
    echo "FAILED: GEMINI_API_KEY was not sanitized"
    exit 1
fi
if grep -q "another-secret" "$MOCK_BUNDLE_DIR/config.json"; then
    echo "FAILED: api_key was not sanitized"
    exit 1
fi
if grep -q "third-secret" "$MOCK_BUNDLE_DIR/config.json"; then
    echo "FAILED: apiKey was not sanitized"
    exit 1
fi

# Verify replacement with ""
if ! grep -q "\"GEMINI_API_KEY\": \"\"" "$MOCK_BUNDLE_DIR/config.json"; then
    echo "FAILED: GEMINI_API_KEY was not replaced with \"\""
    exit 1
fi

# 5. Verify extension-enablement.json
if grep -q "ComputerUse" "$MOCK_BUNDLE_DIR/extensions/extension-enablement.json"; then
    echo "FAILED: ComputerUse still present in extension-enablement.json"
    exit 1
fi
if grep -q "adb-control-gemini" "$MOCK_BUNDLE_DIR/extensions/extension-enablement.json"; then
    echo "FAILED: adb-control-gemini still present in extension-enablement.json"
    exit 1
fi
if ! grep -q "ValidExtension" "$MOCK_BUNDLE_DIR/extensions/extension-enablement.json"; then
    echo "FAILED: ValidExtension missing from extension-enablement.json"
    exit 1
fi

echo "SUCCESS: All tests passed!"
