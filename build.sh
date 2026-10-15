#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "[1/3] Generating AppIcon.icns..."
mkdir -p MiniKVM.app/Contents/MacOS MiniKVM.app/Contents/Resources
swiftc -swift-version 5 generate_icns.swift -o /tmp/minikvm_gen_icns -framework Cocoa
/tmp/minikvm_gen_icns
rm -f /tmp/minikvm_gen_icns $'MiniKVM.app/Icon\r'

echo "[2/3] Compiling MiniKVM.swift..."
swiftc -swift-version 5 -O MiniKVM.swift \
  -o MiniKVM.app/Contents/MacOS/MiniKVM \
  -framework Cocoa \
  -framework AVFoundation \
  -framework CoreMedia \
  -framework CoreVideo \
  -framework CoreText

echo "[3/3] Signing MiniKVM.app..."
xattr -cr MiniKVM.app
codesign --force --deep --sign - MiniKVM.app
touch MiniKVM.app

echo "✅ Build complete: $(pwd)/MiniKVM.app"
