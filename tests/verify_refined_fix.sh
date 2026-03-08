#!/bin/bash

# Final verification of sed fallback with | escaping

CONFIG_FILE="test_config.json"

test_sed_logic() {
    local API_KEY="$1"
    echo "Testing SED with API_KEY: $API_KEY"
    echo '{"GEMINI_API_KEY": "old-key"}' > "$CONFIG_FILE"

    API_KEY_ESC=$(echo "$API_KEY" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/&/\\\&/g' -e 's/|/\\|/g')
    if grep -q "GEMINI_API_KEY" "$CONFIG_FILE"; then
        sed -i "s|\"GEMINI_API_KEY\"[[:space:]]*:[[:space:]]*\".*\"|\"GEMINI_API_KEY\": \"$API_KEY_ESC\"|" "$CONFIG_FILE"
    fi

    echo "Resulting config content:"
    cat "$CONFIG_FILE"
    echo "-------------------"
}

# 1. Test with slash
test_sed_logic "key/with/slash"

# 2. Test with ampersand
test_sed_logic "key&with&ampersand"

# 3. Test with double quote
test_sed_logic 'key"with"quote'

# 4. Test with backslash
test_sed_logic 'key\with\backslash'

# 5. Test with |
test_sed_logic 'key|with|pipe'

rm "$CONFIG_FILE"
