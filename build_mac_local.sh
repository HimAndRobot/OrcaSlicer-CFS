#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"
SAFE_BRANCH="$(printf '%s' "$BRANCH" | sed 's/[^A-Za-z0-9._-]/_/g')"
BUILD_DIR="$REPO_DIR/build-$SAFE_BRANCH"
DEPS_BUILD_DIR="$REPO_DIR/deps/build-$SAFE_BRANCH"

echo "Branch: $BRANCH"
echo "Deps build dir: $DEPS_BUILD_DIR"
echo "Build dir: $BUILD_DIR"

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake not found in PATH"
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git not found in PATH"
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found in PATH"
  exit 1
fi

if command -v git-lfs >/dev/null 2>&1; then
  git -C "$REPO_DIR" lfs pull
fi

mkdir -p "$DEPS_BUILD_DIR"
cd "$DEPS_BUILD_DIR"

echo "Building dependencies..."
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j"$(sysctl -n hw.ncpu)"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "Building OrcaSlicer..."
cmake .. -DORCA_TOOLS=ON -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j"$(sysctl -n hw.ncpu)"

echo
echo "Build finished for branch: $BRANCH"
echo "Build directory: $BUILD_DIR"
echo "Likely outputs:"
find "$BUILD_DIR/src" -maxdepth 2 \( -name "*.app" -o -name "OrcaSlicer_profile_validator" -o -name "orca-slicer" \) 2>/dev/null || true
