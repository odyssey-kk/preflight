#!/usr/bin/env bash
# preflight SessionStart hook script for Claude Code plugin.
# Injecting additional context so Claude can explain what it plans to do before executing any unfamiliar commands, improving reviewability and security.

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="${LOG_FILE:-/tmp/preflight_hook.log}"
readonly MAX_RETRIES="${MAX_RETRIES:-3}"
readonly RETRY_DELAY="${RETRY_DELAY:-1}"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if [[ "$level" == "ERROR" ]]; then
        echo "[$timestamp] [$level] $message" >&2
    fi
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with code $exit_code"
    fi
    return $exit_code
}
trap cleanup EXIT

# JSON validation function
validate_json() {
    local json_string="$1"
    # Use jq if available, otherwise use basic regex validation
    if command -v jq &> /dev/null; then
        echo "$json_string" | jq -e . > /dev/null 2>&1
        return $?
    else
        # Basic JSON validation without jq - POSIX compatible
        local trimmed
        trimmed="$(echo "$json_string" | sed 's/[[:space:]]//g')"
        if [[ "$trimmed" =~ ^\{.*\}$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# JSON escape function with error handling
json_escape() {
    local value="$1"
    if [[ -z "$value" ]]; then
        echo ""
        return 1
    fi
    # Use Python if available for proper JSON escaping, otherwise use printf + sed
    if command -v python3 &> /dev/null; then
        python3 -c 'import json,sys; print(json.dumps(sys.stdin.read(), ensure_ascii=False))' <<< "$value" | sed 's/^"//;s/"$//'
    elif command -v python &> /dev/null; then
        python -c 'import json,sys; print(json.dumps(sys.stdin.read(), ensure_ascii=False))' <<< "$value" | sed 's/^"//;s/"$//'
    else
        # Manual escaping using printf to handle newlines correctly
        local escaped=""
        while IFS= read -r -n1 char; do
            case "$char" in
                \\) escaped="$escaped\\\\" ;;
                $'\n') escaped="$escaped\\n" ;;
                $'\r') escaped="$escaped\\r" ;;
                $'\t') escaped="$escaped\\t" ;;
                \") escaped="$escaped\\\"" ;;
                *) escaped="$escaped$char" ;;
            esac
        done <<< "$value"
        printf '%s' "$escaped"
    fi
}

# Retry mechanism
retry_with_backoff() {
    local max_attempts="$1"
    local delay="$2"
    local command=("${@:3}")
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Attempt $attempt of $max_attempts"
        if "${command[@]}"; then
            log_info "Command succeeded on attempt $attempt"
            return 0
        else
            log_warn "Command failed on attempt $attempt"
            if [[ $attempt -lt $max_attempts ]]; then
                log_info "Retrying in ${delay}s..."
                sleep "$delay"
                delay=$((delay * 2))  # Exponential backoff
            fi
        fi
        attempt=$((attempt + 1))
    done

    log_error "Command failed after $max_attempts attempts"
    return 1
}

# Main script execution
main() {
    log_info "Starting $SCRIPT_NAME"

    local additional_context
    read -r -d '' additional_context <<'EOF' || true
When acting as a Google Senior Architect, Claude Code must follow these cc-buddy rules for Bash, Edit, Write, and MultiEdit operations.

Before any non-trivial operation, it outputs a one-line explanation starting with 'ദി(⎚_⎚ )', written in the same language as the user's most recent message.

The explanation consists of 2–3 short clauses separated by commas, with no final period, and briefly describes the intent of the operation.

If a tool or library is involved, it should state what the tool or library does.

If the operation has risks or side effects, it should clearly call them out.

Examples:
ദി(⎚_⎚ ) Install ESLint dependencies, configure TypeScript parser, set up linting rules for code quality.
ദി(⎚_⎚ ) Create new React component file, implement API data fetching with axios, render data in responsive table layout.
ദി(⎚_⎚ ) Create database dump using pg_dump, compress backup file, this operation may impact database performance temporarily.

For trivial commands such as (`ls`, `cd`, `cat`, `pwd`, and `git status`, etc), it skips the explanation and executes directly.
The 'ദി(⎚_⎚ )' line describes only the semantic intent, and must not repeat filenames, concrete commands, or diff contents.
EOF

    local escaped_context
    if ! escaped_context="$(json_escape "$additional_context")"; then
        log_error "Failed to escape JSON context"
        echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","error":"JSON escape failed"}}'
        return 1
    fi

    local json_output
    json_output=$(cat <<JSONEOF
{
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "${escaped_context}"
    }
}
JSONEOF
)

    # Validate output JSON before printing
    if ! validate_json "$json_output"; then
        log_error "Generated JSON is invalid"
        echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","error":"Invalid JSON generated"}}'
        return 1
    fi

    echo "$json_output"
    log_info "$SCRIPT_NAME completed successfully"
    return 0
}

# Execute main with retry
if [[ "${ENABLE_RETRY:-false}" == "true" ]]; then
    retry_with_backoff "$MAX_RETRIES" "$RETRY_DELAY" main
else
    main
fi
exit $?