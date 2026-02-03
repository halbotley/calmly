#!/bin/bash
set -e

echo "Building calmly..."
swiftc -O -o calmly Sources/calmly.swift

echo "Installing to /usr/local/bin..."
sudo cp calmly /usr/local/bin/
sudo chmod +x /usr/local/bin/calmly

echo "✓ calmly installed successfully!"
echo ""
echo "Try it out:"
echo "  calmly list"
echo "  calmly events Work 7"
echo "  calmly add Work \"Meeting\" 2025-03-15"
