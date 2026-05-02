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
ACTIVE_DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
RAW_ARCH="$(uname -m)"

case "$RAW_ARCH" in
  arm64|aarch64)
    OSX_ARCH="arm64"
    ;;
  x86_64|amd64)
    OSX_ARCH="x86_64"
    ;;
  *)
    echo "Unsupported macOS architecture: $RAW_ARCH"
    exit 1
    ;;
esac

if [ -d "/opt/homebrew/opt/texinfo/bin" ]; then
  export PATH="/opt/homebrew/opt/texinfo/bin:$PATH"
elif [ -d "/usr/local/opt/texinfo/bin" ]; then
  export PATH="/usr/local/opt/texinfo/bin:$PATH"
fi

if [ -n "$ACTIVE_DEV_DIR" ] && [[ "$ACTIVE_DEV_DIR" == *"CommandLineTools"* ]]; then
  echo "xcode-select is still pointing to CommandLineTools:"
  echo "  $ACTIVE_DEV_DIR"
  echo "Switch it first:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

if command -v xcrun >/dev/null 2>&1; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-$ACTIVE_DEV_DIR}"
  export SDKROOT="${SDKROOT:-$(xcrun --show-sdk-path)}"
  export CC="${CC:-$(xcrun --find cc)}"
  export CXX="${CXX:-$(xcrun --find c++)}"
fi

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

if ! command -v makeinfo >/dev/null 2>&1; then
  echo "makeinfo not found in PATH"
  echo "Install texinfo with:"
  echo "  brew install texinfo"
  exit 1
fi

if command -v git-lfs >/dev/null 2>&1; then
  git -C "$REPO_DIR" lfs pull
fi

mkdir -p "$LOG_DIR"

echo "Using CMake: $CMAKE_BIN"
"$CMAKE_BIN" --version | head -n 1
echo "OSX arch: $OSX_ARCH"
echo "Developer dir: ${DEVELOPER_DIR:-<unset>}"
echo "SDKROOT: ${SDKROOT:-<unset>}"
echo "CC: ${CC:-<unset>}"
echo "CXX: ${CXX:-<unset>}"

if "$CMAKE_BIN" --version | head -n 1 | grep -Eq '^cmake version 4\.' && [[ "$BRANCH" == *"v2.3.2"* ]]; then
  echo "Branch v2.3.2 should be built with CMake 3.x on macOS too."
  echo "Install 3.31.x and rerun with:"
  echo "ORCA_CMAKE_BIN=\$HOME/.local/cmake-3.31.12-macos-universal/CMake.app/Contents/bin/cmake ./build_mac_local.sh"
  exit 1
fi

mkdir -p "$DEPS_BUILD_DIR"
cd "$DEPS_BUILD_DIR"

echo "Building dependencies..."
"$CMAKE_BIN" .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="$OSX_ARCH" 2>&1 | tee "$LOG_DIR/deps-configure.log"
"$CMAKE_BIN" --build . --config Release -j1 2>&1 | tee "$LOG_DIR/deps-build.log"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "Building OrcaSlicer..."
"$CMAKE_BIN" .. -DORCA_TOOLS=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="$OSX_ARCH" 2>&1 | tee "$LOG_DIR/orca-configure.log"
"$CMAKE_BIN" --build . --config Release -j"$NPROC" 2>&1 | tee "$LOG_DIR/orca-build.log"

echo
echo "Build finished for branch: $BRANCH"
echo "Build directory: $BUILD_DIR"
echo "Likely outputs:"
find "$BUILD_DIR/src" -maxdepth 2 \( -name "*.app" -o -name "OrcaSlicer_profile_validator" -o -name "orca-slicer" \) 2>/dev/null || true
