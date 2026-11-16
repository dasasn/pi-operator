#!/usr/bin/env bash
# scripts/install-tools.sh — pasang rg dan fd sesuai platform.
#
#   bash scripts/install-tools.sh            # pasang ke ~/.free-pi/agent/bin
#   bash scripts/install-tools.sh --check    # cek saja
#
# Linux x86_64/aarch64 : unduh binary statis dari GitHub release
# Termux (android)     : pakai pkg install (binary Termux, bukan glibc)
# macOS                : brew kalau ada, kalau tidak unduh binary
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${FREEPI_BIN:-$HOME/.free-pi/agent/bin}"
PLATFORM="$(bash "$HERE/detect-platform.sh")"
MODE="${1:-install}"

RG_VER="15.2.0"
FD_VER="10.5.1"

say() { printf '%s\n' "$*"; }

say "platform : $PLATFORM"
say "tujuan   : $DEST"

check_one() {
  local name="$1" p="$DEST/$1"
  if [ -x "$p" ]; then
    say "  $name: $("$p" --version 2>&1 | head -1)"
  else
    say "  $name: TIDAK ADA"
    return 1
  fi
}

if [ "$MODE" = "--check" ]; then
  rc=0
  check_one rg || rc=1
  check_one fd || rc=1
  exit $rc
fi

mkdir -p "$DEST"

# ---------- Termux ----------
if [ "$PLATFORM" = "android-aarch64" ] || [ "$PLATFORM" = "android-armv7" ] || [ "$PLATFORM" = "android-x86_64" ]; then
  say ""
  say "Termux terdeteksi — pakai paket Termux (bukan binary glibc)"
  if ! command -v pkg >/dev/null 2>&1; then
    say "  GAGAL: 'pkg' tidak ada. Ini bukan Termux yang benar."
    exit 1
  fi
  pkg install -y ripgrep fd >/dev/null 2>&1 || {
    say "  pkg install gagal, coba update dulu"
    pkg update -y >/dev/null 2>&1
    pkg install -y ripgrep fd
  }
  for n in rg fd; do
    src="$(command -v "$n" 2>/dev/null)"
    if [ -n "$src" ]; then
      ln -sf "$src" "$DEST/$n"
      say "  $n -> $src"
    else
      say "  $n: TIDAK DITEMUKAN setelah pkg install"
    fi
  done
  say ""
  check_one rg; check_one fd
  exit 0
fi

# ---------- macOS ----------
if [ "$PLATFORM" = "darwin-x86_64" ] || [ "$PLATFORM" = "darwin-aarch64" ]; then
  say ""
  if command -v brew >/dev/null 2>&1; then
    say "macOS + brew — pakai brew"
    brew list ripgrep >/dev/null 2>&1 || brew install ripgrep
    brew list fd >/dev/null 2>&1 || brew install fd
    for n in rg fd; do
      src="$(command -v "$n" 2>/dev/null)"
      [ -n "$src" ] && ln -sf "$src" "$DEST/$n" && say "  $n -> $src"
    done
  else
    say "macOS tanpa brew — unduh binary"
    tgt="aarch64-apple-darwin"; [ "$PLATFORM" = "darwin-x86_64" ] && tgt="x86_64-apple-darwin"
    tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/$RG_VER/ripgrep-$RG_VER-$tgt.tar.gz" | tar xz -C "$tmp" && \
      cp "$tmp"/ripgrep-*/rg "$DEST/rg" && say "  rg terpasang"
    curl -fsSL "https://github.com/sharkdp/fd/releases/download/v$FD_VER/fd-v$FD_VER-$tgt.tar.gz" | tar xz -C "$tmp" && \
      cp "$tmp"/fd-v*/fd "$DEST/fd" && say "  fd terpasang"
    rm -rf "$tmp"
  fi
  chmod +x "$DEST"/rg "$DEST"/fd 2>/dev/null
  say ""
  check_one rg; check_one fd
  exit 0
fi


# ---------- fallback: pakai yang sudah ada di sistem ----------
# Kalau unduhan gagal (offline, DNS mati, proxy), jangan biarkan kosong.
fallback_system() {
  local n="$1" src
  src="$(command -v "$n" 2>/dev/null)"
  if [ -n "$src" ]; then
    ln -sf "$src" "$DEST/$n"
    say "    fallback: $n -> $src"
    return 0
  fi
  return 1
}

# ---------- Linux ----------
case "$PLATFORM" in
  linux-x86_64) rg_tgt="x86_64-unknown-linux-musl"; fd_tgt="x86_64-unknown-linux-musl" ;;
  linux-aarch64) rg_tgt="aarch64-unknown-linux-gnu"; fd_tgt="aarch64-unknown-linux-musl" ;;
  linux-armv7) rg_tgt="armv7-unknown-linux-gnueabihf"; fd_tgt="armv7-unknown-linux-musleabihf" ;;
  *) say "platform $PLATFORM belum dipetakan — pasang rg/fd manual"; exit 1 ;;
esac

say ""
say "Linux — unduh binary statis"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say "  rg $RG_VER ($rg_tgt)"
if curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/$RG_VER/ripgrep-$RG_VER-$rg_tgt.tar.gz" \
     | tar xz -C "$tmp" 2>/dev/null; then
  cp "$tmp"/ripgrep-*/rg "$DEST/rg" && chmod +x "$DEST/rg" && say "    ok"
else
  say "    GAGAL unduh rg"
fi

say "  fd $FD_VER ($fd_tgt)"
if curl -fsSL "https://github.com/sharkdp/fd/releases/download/v$FD_VER/fd-v$FD_VER-$fd_tgt.tar.gz" \
     | tar xz -C "$tmp" 2>/dev/null; then
  cp "$tmp"/fd-v*/fd "$DEST/fd" && chmod +x "$DEST/fd" && say "    ok"
else
  say "    GAGAL unduh fd"
fi

# Kalau unduhan gagal, coba pakai yang ada di sistem.
[ -x "$DEST/rg" ] || fallback_system rg || say "  rg tidak tersedia — pasang manual: apt install ripgrep"
[ -x "$DEST/fd" ] || fallback_system fd || say "  fd tidak tersedia — pasang manual: apt install fd-find"

say ""
rc=0
check_one rg || rc=1
check_one fd || rc=1
exit $rc
