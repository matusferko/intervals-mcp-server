#!/usr/bin/env bash
#
# Install all dependencies for the Intervals.icu MCP Server on macOS.
#
# Usage: ./scripts/macos/step1-install.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "==> Installing Intervals.icu MCP Server dependencies (repo: $REPO_ROOT)"

# 1. Ensure uv is installed
if ! command -v uv >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo "==> Installing uv via Homebrew..."
        brew install uv
    else
        echo "==> Homebrew not found. Installing uv via the official installer..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        # The installer places uv in ~/.local/bin
        export PATH="$HOME/.local/bin:$PATH"
    fi
else
    echo "==> uv is already installed ($(uv --version))"
fi

# 2. Create the virtual environment with Python 3.12 (uv downloads it if missing)
if [ ! -d .venv ]; then
    echo "==> Creating virtual environment (.venv) with Python 3.12..."
    uv venv --python 3.12
else
    echo "==> Virtual environment already exists (.venv)"
fi

# 3. Install project dependencies (including dev extras: pytest, mypy, ruff, ...)
echo "==> Syncing dependencies..."
uv sync --all-extras

# 4. Set up the .env file
if [ ! -f .env ]; then
    echo "==> Creating .env from .env.example..."
    cp .env.example .env
    echo ""
    echo "    ACTION REQUIRED: edit .env and set your API_KEY and ATHLETE_ID."
    echo "    Get your API key at: https://intervals.icu/settings (Developer Settings)"
else
    echo "==> .env already exists, leaving it untouched"
fi

echo ""
echo "==> Done. Start the server with: ./scripts/macos/step2-run.sh"
