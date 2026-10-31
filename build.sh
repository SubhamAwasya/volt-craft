#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "Building VoltCraft Pro (Ultra-lightweight AlDente Pro Dashboard clone)..."
make clean
make all
make size

echo ""
echo "Build complete! You can run:"
echo "  CLI:  ./voltcraft status"
echo "  App:  open VoltCraft.app"
