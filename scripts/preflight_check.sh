#!/usr/bin/env bash
# preflight SessionStart hook script for Claude Code plugin.
# Injecting additionalcontext so Claude can explains what it plans to do before executing any unfamiliar commands, improving reviewability and security.

json_escape() {
  local value=$1
  local quote='"'
  value=${value//\\/\\\\}
  value=${value//$quote/\\$quote}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

read -r -d '' ADDITIONAL_CONTEXT <<'EOF' || true
When acting as a Google Senior Architect, Claude Code must follow these cc-buddy rules for Bash, Edit, Write, and MultiEdit operations.

Before any non-trivial operation, it outputs a one-line explanation starting with 'ദി(⎚_⎚ )', written in the same language as the user’s most recent message.

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


cat <<JSONEOF
{
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "$(json_escape "$ADDITIONAL_CONTEXT")"
    }
}
JSONEOF


exit 0