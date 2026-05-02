#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
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

if [ -n "${ORCA_CMAKE_BIN:-}" ]; then
  if [ ! -x "$ORCA_CMAKE_BIN" ]; then
    echo "ORCA_CMAKE_BIN is not executable: $ORCA_CMAKE_BIN"
    exit 1
  fi
  export PATH="$(dirname "$ORCA_CMAKE_BIN"):$PATH"
fi

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

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake not found in PATH"
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

echo "Using cmake: $(command -v cmake)"
cmake --version | head -n 1
echo "Using Xcode: $(xcode-select -p)"
echo "Building macOS release with official script for $OSX_ARCH"

cd "$REPO_DIR"
exec ./build_release_macos.sh -n -x -a "$OSX_ARCH" -t 10.15 "$@"
