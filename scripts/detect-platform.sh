#!/usr/bin/env bash
# scripts/detect-platform.sh — deteksi OS/arsitektur untuk memilih binary yang benar.
# Output: satu baris "<os>-<arch>" mis. linux-x86_64, linux-aarch64, android-aarch64
set -uo pipefail

os="linux"
case "$(uname -s)" in
  Linux) os="linux" ;;
  Darwin) os="darwin" ;;
  *) os="$(uname -s | tr '[:upper:]' '[:lower:]')" ;;
esac

# Termux = Android userspace, binary harus dari paket Termux, bukan glibc/musl
if [ -n "${PREFIX:-}" ] && [ -d "${PREFIX:-}/bin" ]; then
  case "$PREFIX" in
    *com.termux*) os="android" ;;
  esac
fi

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) arch="x86_64" ;;
  aarch64|arm64) arch="aarch64" ;;
  armv7l|armv8l) arch="armv7" ;;
  i686|i386) arch="i686" ;;
esac

printf '%s-%s\n' "$os" "$arch"
