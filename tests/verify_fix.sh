#!/bin/bash

# Verification of the fixed logic

CONFIG_FILE="test_config.json"

test_key_logic() {
    local API_KEY="$1"
    echo "Testing with API_KEY: $API_KEY"

    # Setup dummy config
    echo '{"GEMINI_API_KEY": "old-key"}' > "$CONFIG_FILE"

    # Mimic the fixed logic (using python3 as it is most likely available in this env)
    export API_KEY
    export CONFIG_FILE
    python3 -c '
import json, os, sys
config_file = os.environ["CONFIG_FILE"]
api_key = os.environ["API_KEY"]
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
with open(config_file, "w") as f:
    json.dump(data, f, indent=2)
'

    echo "Resulting config content:"
    cat "$CONFIG_FILE"
    echo "-------------------"
}

# 1. Test with slash
test_key_logic "key/with/slash"

# 2. Test with ampersand
test_key_logic "key&with&ampersand"

# 3. Test with double quote
test_key_logic 'key"with"quote'

rm "$CONFIG_FILE"
