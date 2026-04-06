#!/bin/bash
set -e

echo "=== Installing Flutter (stable) ==="
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"
flutter config --no-analytics --no-cli-animations

echo "=== flutter pub get ==="
flutter pub get

echo "=== flutter build web ==="
flutter build web --release --web-renderer canvaskit

echo "=== Build complete: build/web ==="
