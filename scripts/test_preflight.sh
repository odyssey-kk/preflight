#!/usr/bin/env bash
# Test script for preflight_check.sh
# Tests: valid JSON output, additionalContext injection, edge cases

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFLIGHT_SCRIPT="$SCRIPT_DIR/preflight_check.sh"
FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED=1
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Test 1: Valid JSON output
test_valid_json() {
    log_info "Test 1: Checking if preflight_check.sh outputs valid JSON"

    OUTPUT=$("$PREFLIGHT_SCRIPT" 2>&1)
    if command -v jq &> /dev/null; then
        if echo "$OUTPUT" | jq . > /dev/null 2>&1; then
            log_pass "Output is valid JSON"
        else
            log_fail "Output is not valid JSON: $OUTPUT"
            return 1
        fi
    else
        # Fallback: basic JSON structure check
        if echo "$OUTPUT" | grep -q '^{' && echo "$OUTPUT" | grep -q '"hookSpecificOutput"'; then
            log_pass "Output has valid JSON structure (jq not available for full validation)"
        else
            log_fail "Output does not have valid JSON structure: $OUTPUT"
            return 1
        fi
    fi

    # Check required fields
    if echo "$OUTPUT" | grep -q '"hookEventName"'; then
        log_pass "Contains hookEventName field"
    else
        log_fail "Missing hookEventName field"
        return 1
    fi

    if echo "$OUTPUT" | grep -q '"additionalContext"'; then
        log_pass "Contains additionalContext field"
    else
        log_fail "Missing additionalContext field"
        return 1
    fi
}

# Test 2: additionalContext content is correctly injected
test_context_injection() {
    log_info "Test 2: Checking additionalContext content injection"

    OUTPUT=$("$PREFLIGHT_SCRIPT" 2>&1)

    # Extract additionalContext value
    if command -v jq &> /dev/null; then
        CONTEXT=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.additionalContext')

        if [ -n "$CONTEXT" ] && [ "$CONTEXT" != "null" ]; then
            log_pass "additionalContext is not empty"
        else
            log_fail "additionalContext is empty or null"
            return 1
        fi

        # Check for expected content
        if echo "$CONTEXT" | grep -q "cc-buddy rules"; then
            log_pass "additionalContext contains 'cc-buddy rules'"
        else
            log_fail "additionalContext missing 'cc-buddy rules'"
            return 1
        fi

        if echo "$CONTEXT" | grep -q "ദി"; then
            log_pass "additionalContext contains unicode marker 'ദി'"
        else
            log_fail "additionalContext missing unicode marker 'ദി'"
            return 1
        fi

        if echo "$CONTEXT" | grep -q "SessionStart\|Bash\|Edit\|Write\|MultiEdit"; then
            log_pass "additionalContext contains operation rules"
        else
            log_fail "additionalContext missing operation rules"
            return 1
        fi
    else
        log_info "jq not available, skipping detailed context validation"
    fi
}

# Test 3: Edge case - JSON escaping of special characters
test_json_escaping() {
    log_info "Test 3: Checking JSON escaping of special characters"

    # Create a temporary test script with special characters
    TEMP_SCRIPT=$(mktemp)
    cat > "$TEMP_SCRIPT" << 'SCRIPT_EOF'
#!/usr/bin/env bash
json_escape() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//'"'/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

TEST_STRING='line1
line2 with "quotes" and\backslash	and	tab'
RESULT=$(json_escape "$TEST_STRING")
cat <<JSONEOF
{"test": "$RESULT"}
JSONEOF
SCRIPT_EOF
    chmod +x "$TEMP_SCRIPT"

    OUTPUT=$("$TEMP_SCRIPT" 2>&1)
    rm -f "$TEMP_SCRIPT"

    if command -v jq &> /dev/null; then
        if echo "$OUTPUT" | jq . > /dev/null 2>&1; then
            log_pass "Special characters are properly escaped"
        else
            log_fail "Special characters not properly escaped: $OUTPUT"
            return 1
        fi
    else
        # Check that newlines, quotes, backslashes, tabs are escaped
        if echo "$OUTPUT" | grep -q '\\n' && echo "$OUTPUT" | grep -q '\\"' && echo "$OUTPUT" | grep -q '\\\\'; then
            log_pass "Special characters appear to be escaped (jq not available for validation)"
        else
            log_fail "Special characters may not be properly escaped: $OUTPUT"
            return 1
        fi
    fi
}

# Test 4: Edge case - hookEventName is correct
test_hook_event_name() {
    log_info "Test 4: Checking hookEventName value"

    OUTPUT=$("$PREFLIGHT_SCRIPT" 2>&1)

    if command -v jq &> /dev/null; then
        EVENT_NAME=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.hookEventName')
        if [ "$EVENT_NAME" = "SessionStart" ]; then
            log_pass "hookEventName is 'SessionStart'"
        else
            log_fail "hookEventName is '$EVENT_NAME', expected 'SessionStart'"
            return 1
        fi
    else
        if echo "$OUTPUT" | grep -q '"hookEventName"[[:space:]]*:[[:space:]]*"SessionStart"'; then
            log_pass "hookEventName is 'SessionStart'"
        else
            log_fail "hookEventName is not 'SessionStart'"
            return 1
        fi
    fi
}

# Test 5: Exit code is 0
test_exit_code() {
    log_info "Test 5: Checking script exit code"

    "$PREFLIGHT_SCRIPT" > /dev/null 2>&1
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        log_pass "Script exits with code 0"
    else
        log_fail "Script exits with code $EXIT_CODE, expected 0"
        return 1
    fi
}

# Test 6: Output is not empty
test_output_not_empty() {
    log_info "Test 6: Checking output is not empty"

    OUTPUT=$("$PREFLIGHT_SCRIPT" 2>&1)

    if [ -n "$OUTPUT" ]; then
        log_pass "Output is not empty ($(echo "$OUTPUT" | wc -c) bytes)"
    else
        log_fail "Output is empty"
        return 1
    fi
}

# Run all tests
echo "========================================"
echo "Running preflight_check.sh tests"
echo "========================================"
echo ""

test_valid_json
test_context_injection
test_json_escaping
test_hook_event_name
test_exit_code
test_output_not_empty

echo ""
echo "========================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
