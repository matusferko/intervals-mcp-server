#!/usr/bin/env bash
#
# Run the Intervals.icu MCP Server on macOS.
#
# Usage:
#   ./scripts/macos/step2-run.sh              # stdio transport (default, for Claude Desktop)
#   MCP_TRANSPORT=sse ./scripts/macos/step2-run.sh    # SSE transport (e.g. for ChatGPT connectors)
#   MCP_TRANSPORT=http ./scripts/macos/step2-run.sh   # Streamable HTTP transport

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Make sure uv is on PATH (covers the official-installer location)
export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
    echo "Error: uv not found. Run ./scripts/macos/step1-install.sh first." >&2
    exit 1
fi

if [ ! -d .venv ]; then
    echo "Error: .venv not found. Run ./scripts/macos/step1-install.sh first." >&2
    exit 1
fi

if [ ! -f .env ]; then
    echo "Warning: no .env file found. The server needs API_KEY and ATHLETE_ID" >&2
    echo "         (copy .env.example to .env and fill in your values)." >&2
fi

# Validate ATHLETE_ID format if set (env var wins over .env, matching the server).
# Allowed: all digits (e.g. 123456) or 'i' + digits (e.g. i123456).
ATHLETE_ID_VALUE="${ATHLETE_ID:-$( [ -f .env ] && grep -E '^ATHLETE_ID=' .env | tail -1 | cut -d= -f2- | tr -d '[:space:]' )}"
if [ -n "$ATHLETE_ID_VALUE" ] && ! [[ "$ATHLETE_ID_VALUE" =~ ^i?[0-9]+$ ]]; then
    echo "Error: ATHLETE_ID has an invalid format: '$ATHLETE_ID_VALUE'" >&2
    echo "       It must be all digits (e.g. 123456) or 'i' followed by digits (e.g. i123456)." >&2
    exit 1
fi

echo "==> Starting Intervals.icu MCP Server (transport: ${MCP_TRANSPORT:-stdio})..."
exec uv run python src/intervals_mcp_server/server.py
