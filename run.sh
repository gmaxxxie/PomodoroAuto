#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🍅 PomodoroAuto - Quick Run (Development)"
echo ""

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "❌ Error: Swift is not installed"
    echo "   Install Xcode or Swift toolchain from https://swift.org"
    exit 1
fi

# Build and run
echo "🚀 Building and running..."
swift run
