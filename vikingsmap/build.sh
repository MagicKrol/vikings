#!/bin/sh
set -e
mkdir -p build

# Use npx to ensure esbuild is available without requiring a global install
npx --yes esbuild --bundle mapgen2.js --sourcemap --minify --outfile=build/_bundle.js

# Also produce build/bundle.js for compatibility with environments expecting this name
cp build/_bundle.js build/bundle.js 2>/dev/null || true
if [ -f build/_bundle.js.map ]; then
  cp build/_bundle.js.map build/bundle.js.map 2>/dev/null || true
fi
