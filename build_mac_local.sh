#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"
SAFE_BRANCH="$(printf '%s' "$BRANCH" | sed 's/[^A-Za-z0-9._-]/_/g')"
BUILD_DIR="$REPO_DIR/build-$SAFE_BRANCH"
DEPS_BUILD_DIR="$REPO_DIR/deps/build-$SAFE_BRANCH"
LOG_DIR="$REPO_DIR/build-logs-$SAFE_BRANCH"
CMAKE_BIN="${ORCA_CMAKE_BIN:-cmake}"
NPROC="$(sysctl -n hw.ncpu)"

echo "Branch: $BRANCH"
echo "Deps build dir: $DEPS_BUILD_DIR"
echo "Build dir: $BUILD_DIR"
echo "Log dir: $LOG_DIR"

if ! command -v "$CMAKE_BIN" >/dev/null 2>&1; then
  echo "cmake not found: $CMAKE_BIN"
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

mkdir -p "$LOG_DIR"

echo "Using CMake: $CMAKE_BIN"
"$CMAKE_BIN" --version | head -n 1

if "$CMAKE_BIN" --version | head -n 1 | grep -Eq '^cmake version 4\.' && [ "$BRANCH" = "v2.3.2" ]; then
  echo "Branch v2.3.2 should be built with CMake 3.x on macOS too."
  echo "Install 3.31.x and rerun with:"
  echo "ORCA_CMAKE_BIN=/opt/homebrew/bin/cmake ./build_mac_local.sh"
  exit 1
fi

mkdir -p "$DEPS_BUILD_DIR"
cd "$DEPS_BUILD_DIR"

echo "Building dependencies..."
"$CMAKE_BIN" .. -DCMAKE_BUILD_TYPE=Release 2>&1 | tee "$LOG_DIR/deps-configure.log"
"$CMAKE_BIN" --build . --config Release -j1 2>&1 | tee "$LOG_DIR/deps-build.log"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "Building OrcaSlicer..."
"$CMAKE_BIN" .. -DORCA_TOOLS=ON -DCMAKE_BUILD_TYPE=Release 2>&1 | tee "$LOG_DIR/orca-configure.log"
"$CMAKE_BIN" --build . --config Release -j"$NPROC" 2>&1 | tee "$LOG_DIR/orca-build.log"

echo
echo "Build finished for branch: $BRANCH"
echo "Build directory: $BUILD_DIR"
echo "Likely outputs:"
find "$BUILD_DIR/src" -maxdepth 2 \( -name "*.app" -o -name "OrcaSlicer_profile_validator" -o -name "orca-slicer" \) 2>/dev/null || true
