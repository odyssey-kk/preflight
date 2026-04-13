# Preflight

A Claude Code plugin that brings Google Senior Architect-style reviewability to every session.

## Overview

Preflight transforms Claude Code into an architect-grade coding assistant. Before executing any unfamiliar commands or file operations, it provides inline explanations of its intent — improving security, reviewability, and team collaboration.

## Features

- **Intent Transparency**: Before any non-trivial operation, explains what Claude plans to do
- **Architect-Grade Review**: Semantic explanations help teams understand and audit AI actions
- **Zero External Dependencies**: All explanation logic runs locally — no external LLM services involved
- **Seamless Integration**: Works automatically on session start via SessionStart hook

## How It Works

When active, Preflight injects additional context that makes Claude Code output explanations prefixed with `ദി(⎚_⎚ )` before operations such as:

- File creation and editing
- Shell command execution
- Multi-file modifications

Trivial commands (`ls`, `cd`, `cat`, `pwd`, `git status`, etc.) execute directly without explanation.

### Example Output

```
ദി(⎚_⎚ ) Install ESLint dependencies, configure TypeScript parser, set up linting rules for code quality.
```

## Installation

This plugin is distributed via the Claude Code plugin marketplace. To install:

1. Open Claude Code settings
2. Navigate to Plugins
3. Search for "preflight"
4. Click Install

Or via the CLI:

```bash
claude plugins marketplace add odyssey-kk/preflight
claude plugin install preflight@odyssey
```

## Configuration

Preflight works out of the box with no configuration required. The plugin automatically activates on every Claude Code session.

## Hook Details

Preflight uses a `SessionStart` hook that runs a local bash script. This script injects context into Claude Code's session, enabling the explanation behavior without any external services.

| Hook Event | Trigger |
|------------|---------|
| SessionStart | Runs on every Claude Code session start |

## License

MIT License

## Author

Komoribe
