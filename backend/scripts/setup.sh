#!/bin/bash
# Python environment setup with auto-detection

set -e

echo "🐍 Setting up Python environment..."

# Auto-detect Python command
PYTHON_CMD=""
for cmd in python3 python py; do
    if command -v "$cmd" &> /dev/null; then
        # Check if it's Python 3
        if "$cmd" --version 2>&1 | grep -q "Python 3"; then
            PYTHON_CMD="$cmd"
            echo "✅ Found Python: $cmd ($($cmd --version))"
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "❌ No Python 3 installation found!"
    echo "Please install Python 3.8+ and ensure it's in your PATH"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    "$PYTHON_CMD" -m venv .venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source .venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install project dependencies
echo "Installing project dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
elif [ -f "pyproject.toml" ]; then
    pip install -e .
else
    echo "⚠️  No requirements.txt or pyproject.toml found"
fi

echo "✅ Environment ready! Virtual environment activated."
echo "Run: source .venv/bin/activate"
