#!/usr/bin/env bash
#
# Register the Intervals.icu MCP Server with Claude Desktop on macOS.
#
# Run this AFTER ./scripts/macos/step1-install.sh and after filling in your real
# API_KEY and ATHLETE_ID in .env — the values are copied into Claude
# Desktop's config file (claude_desktop_config.json).
#
# Usage: ./scripts/macos/step3-register-claude-mcp.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1 || [ ! -d .venv ]; then
    echo "Error: environment not set up. Run ./scripts/macos/step1-install.sh first." >&2
    exit 1
fi

if [ ! -f .env ]; then
    echo "Error: no .env file found. Copy .env.example to .env and fill in" >&2
    echo "       your API_KEY and ATHLETE_ID before registering." >&2
    exit 1
fi

if grep -qE '^(API_KEY=your_intervals_api_key_here|ATHLETE_ID=your_athlete_id_here)' .env; then
    echo "Error: .env still contains placeholder values. Edit .env and set your" >&2
    echo "       real API_KEY and ATHLETE_ID first — these values get copied into" >&2
    echo "       Claude Desktop's config file." >&2
    exit 1
fi

# Validate ATHLETE_ID format: all digits (e.g. 123456) or 'i' + digits (e.g. i123456)
ATHLETE_ID_VALUE="$(grep -E '^ATHLETE_ID=' .env | tail -1 | cut -d= -f2- | tr -d '[:space:]')"
if ! [[ "$ATHLETE_ID_VALUE" =~ ^i?[0-9]+$ ]]; then
    echo "Error: ATHLETE_ID in .env has an invalid format: '$ATHLETE_ID_VALUE'" >&2
    echo "       It must be all digits (e.g. 123456) or 'i' followed by digits (e.g. i123456)." >&2
    exit 1
fi

echo "==> Registering Intervals.icu MCP Server with Claude Desktop..."
uv run mcp install src/intervals_mcp_server/server.py \
    --name "Intervals.icu" \
    --with-editable . \
    --env-file .env

echo ""
echo "==> Done. Restart Claude Desktop to load the server."
echo "    Look for the tools icon in the chat input to confirm it's connected."
