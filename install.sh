#!/usr/bin/env bash
# install.sh — pasang free-pi + aturan operator di Linux atau Termux.
#
#   bash install.sh              # pasang
#   bash install.sh --dry-run    # lihat apa yang akan dilakukan
#   bash install.sh --rules-only # hanya aturan + guard, jangan sentuh free-pi
#
# Aman dijalankan berulang. Yang sudah ada tidak ditimpa kecuali memang
# bagian dari paket (AGENTS.md, skills, protected).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM="$(bash "$HERE/scripts/detect-platform.sh")"
DRY=0
RULES_ONLY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --rules-only) RULES_ONLY=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
  esac
done

AR="$HOME/.agent-rules"
FP="$HOME/.free-pi"
TS="$(date +%Y%m%d-%H%M%S)"

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then say "  [dry] $*"; else eval "$@"; fi; }
hr()  { say ""; say "--- $* ---"; }

say "platform : $PLATFORM"
say "home     : $HOME"
say "mode     : $([ "$DRY" = 1 ] && echo 'dry-run' || echo 'pasang')$([ "$RULES_ONLY" = 1 ] && echo ' (rules-only)')"

# ============================================================
hr "1. aturan operator"
# ============================================================
run "mkdir -p '$AR/skills' '$AR/protected/agent'"

if [ -f "$AR/operator.AGENTS.md.master" ]; then
  run "cp -a '$AR/operator.AGENTS.md.master' '$AR/operator.AGENTS.md.master.bak-$TS'"
fi
run "cp -f '$HERE/rules/operator.AGENTS.md.master' '$AR/operator.AGENTS.md.master'"
run "chmod 444 '$AR/operator.AGENTS.md.master'"
say "  master: $(sha256sum "$HERE/rules/operator.AGENTS.md.master" | cut -c1-16)"

# skills: salin yang belum ada, jangan hapus yang sudah ada
if [ -d "$HERE/rules/skills" ]; then
  added=0
  while IFS= read -r -d '' d; do
    rel="${d#$HERE/rules/skills/}"
    if [ ! -e "$AR/skills/$rel" ]; then
      run "mkdir -p '$AR/skills/$(dirname "$rel")'"
      run "cp -aL '$d' '$AR/skills/$rel'"
      added=$((added+1))
    fi
  done < <(find "$HERE/rules/skills" -mindepth 1 -maxdepth 1 -print0)
  say "  skills baru: $added (total sekarang: $(ls -1A "$AR/skills" 2>/dev/null | wc -l))"
fi

# protected
if [ -d "$HERE/rules/protected" ]; then
  run "cp -a '$HERE/rules/protected/.' '$AR/protected/'"
  ( cd "$AR/protected" && find . -type f ! -name 'PROTECTED.sha256' -print0 | sort -z | xargs -0 sha256sum > PROTECTED.sha256 )
  say "  protected: $(wc -l < "$AR/protected/PROTECTED.sha256") entri"
fi

run "mkdir -p '$AR/scripts'"
run "cp -f '$HERE/scripts/install-tools.sh' '$AR/scripts/install-tools.sh'"
run "cp -f '$HERE/scripts/detect-platform.sh' '$AR/scripts/detect-platform.sh'"
run "chmod +x '$AR/scripts/'*.sh"
run "cp -f '$HERE/rules/rules-guard.sh' '$AR/rules-guard.sh'"
run "chmod +x '$AR/rules-guard.sh'"
[ -f "$HERE/rules/README.md" ] && run "cp -f '$HERE/rules/README.md' '$AR/README.md'"

# AGENTS.md di home
run "cp -f '$AR/operator.AGENTS.md.master' '$HOME/AGENTS.md'"
run "chmod 444 '$HOME/AGENTS.md'"

# ============================================================
hr "2. symlink aturan ke tiap agent dir"
# ============================================================
link_to() { # $1 = path, $2 = target
  local p="$1" t="$2"
  run "mkdir -p '$(dirname "$p")'"
  if [ -L "$p" ] || [ -f "$p" ]; then run "rm -f '$p'"; fi
  run "ln -sfn '$t' '$p'"
  say "  ${p#$HOME/} -> ${t#$HOME/}"
}
link_to "$HOME/.config/opencode/AGENTS.md" "$HOME/AGENTS.md"
link_to "$HOME/.pi/agent/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
[ -d "$HOME/.agents" ] && link_to "$HOME/.agents/AGENTS.md" "$HOME/AGENTS.md"

# skills symlink untuk tiap agent
for pair in ".claude/skills:$AR/skills" ".agents/skills:$AR/skills" \
            ".pi/agent/skills:$AR/skills" ".free-pi/agent/skills:$AR/skills" \
            ".config/opencode/skill:$AR/skills"; do
  p="${pair%%:*}"; t="${pair##*:}"
  base="$(dirname "$HOME/$p")"
  [ -d "$base" ] || continue
  if [ -e "$HOME/$p" ] && [ ! -L "$HOME/$p" ]; then
    run "mv '$HOME/$p' '$HOME/$p.bak-$TS'"
  fi
  run "ln -sfn '$t' '$HOME/$p'"
  say "  ${p} -> skills"
done

# ============================================================
if [ "$RULES_ONLY" = 0 ]; then
hr "3. free-pi config"
# ============================================================
run "mkdir -p '$FP/agent' '$FP/state'"
if [ -d "$FP/agent" ] && [ "$DRY" = 0 ]; then
  cp -a "$FP/agent" "$FP/agent.bak-$TS" 2>/dev/null
  say "  backup: ~/.free-pi/agent.bak-$TS"
fi
for f in AGENTS.md APPEND_SYSTEM.md operator-gate.md models.json default-model.json mcp.json; do
  [ -f "$HERE/config/free-pi/agent/$f" ] && run "cp -f '$HERE/config/free-pi/agent/$f' '$FP/agent/$f'"
done
[ -d "$HERE/config/free-pi/agent/extensions" ] && run "cp -a '$HERE/config/free-pi/agent/extensions/.' '$FP/agent/extensions/'"
run "chmod 444 '$FP/agent/AGENTS.md' '$FP/agent/APPEND_SYSTEM.md' 2>/dev/null"

# state: maint.sh, pinned, patcher
for f in maint.sh models-local.json models-merge.cjs; do
  [ -f "$HERE/config/free-pi/state/$f" ] && run "cp -f '$HERE/config/free-pi/state/$f' '$FP/state/$f'"
done
if [ -d "$HERE/config/free-pi/state/pinned" ]; then
  run "mkdir -p '$FP/state/pinned'"
  run "cp -f '$HERE/config/free-pi/state/pinned/'*.js '$FP/state/pinned/'"
  say "  pinned: $(ls -1 "$FP/state/pinned" 2>/dev/null | tr '\n' ' ')"
fi
for f in bundle-patch.cjs check-bundle.cjs find-pkg.cjs free-pi; do
  [ -f "$HERE/config/free-pi/$f" ] && { run "mkdir -p '$FP/bin'"; run "cp -f '$HERE/config/free-pi/$f' '$FP/bin/$f'"; }
done
run "chmod +x '$FP/bin/'*.cjs '$FP/bin/free-pi' 2>/dev/null"

# ============================================================
hr "4. rg & fd sesuai platform"
# ============================================================
if [ "$DRY" = 1 ]; then
  say "  [dry] bash scripts/install-tools.sh"
else
  bash "$HERE/scripts/install-tools.sh" || say "  PERINGATAN: rg/fd gagal dipasang — pi tetap jalan, tapi tool cari file tidak"
fi

# ============================================================
hr "5. coarena (kalau ada)"
# ============================================================
if [ -d "$HERE/coarena" ] && [ -n "$(ls -A "$HERE/coarena" 2>/dev/null)" ]; then
  run "mkdir -p '$HOME/.pi/agent/extensions'"
  [ -f "$HERE/coarena/extensions/coarena-feedback.ts" ] && \
    run "cp -f '$HERE/coarena/extensions/coarena-feedback.ts' '$HOME/.pi/agent/extensions/'"
  [ -f "$HERE/coarena/models.json" ] && run "cp -f '$HERE/coarena/models.json' '$HOME/.pi/agent/models.json'"
  [ -f "$HERE/coarena/README-coarena.md" ] && run "cp -f '$HERE/coarena/README-coarena.md' '$HOME/.pi/agent/'"
  say "  coarena terpasang (API key TIDAK disertakan — isi sendiri di ~/.pi/agent/.env)"
else
  say "  dilewati (tidak ada di repo)"
fi
fi

# ============================================================
hr "6. jadwal guard"
# ============================================================
if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
  say "  systemd --user terdeteksi"
  run "mkdir -p '$HOME/.config/systemd/user'"
  if [ "$DRY" = 0 ]; then
    cat > "$HOME/.config/systemd/user/rules-guard.service" <<EOF
[Unit]
Description=Sync operator rules to all agent dirs

[Service]
Type=oneshot
ExecStart=/bin/bash $AR/rules-guard.sh
EOF
    cat > "$HOME/.config/systemd/user/rules-guard.timer" <<EOF
[Unit]
Description=Run rules-guard every minute

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s

[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now rules-guard.timer >/dev/null 2>&1
    say "  rules-guard.timer: $(systemctl --user is-active rules-guard.timer)"
  else
    say "  [dry] tulis rules-guard.service + .timer, enable"
  fi
elif [ "$PLATFORM" = "android-aarch64" ] || [ "$PLATFORM" = "android-armv7" ] || [ "$PLATFORM" = "android-x86_64" ]; then
  say "  Termux (tanpa systemd) — pakai hook shell"
  if [ "$DRY" = 0 ]; then
    HOOK="$HOME/.bashrc"
    touch "$HOOK"
    if ! grep -q 'rules-guard-hook' "$HOOK" 2>/dev/null; then
      cat >> "$HOOK" <<EOF

# rules-guard-hook: jalankan guard tiap 60 detik di latar belakang
if [ -x "$AR/rules-guard.sh" ]; then
  if [ ! -f "\$HOME/.agent-rules/.guard.pid" ] || ! kill -0 "\$(cat "\$HOME/.agent-rules/.guard.pid" 2>/dev/null)" 2>/dev/null; then
    ( while true; do bash "$AR/rules-guard.sh" >/dev/null 2>&1; sleep 60; done & echo \$! > "\$HOME/.agent-rules/.guard.pid" )
  fi
fi
EOF
      say "  hook ditambahkan ke ~/.bashrc"
    else
      say "  hook sudah ada"
    fi
    bash "$AR/rules-guard.sh" >/dev/null 2>&1
    say "  guard dijalankan sekali sekarang"
  else
    say "  [dry] tambah hook ke ~/.bashrc + jalankan guard"
  fi
else
  say "  tidak ada systemd dan bukan Termux — jalankan manual:"
  say "    bash $AR/rules-guard.sh"
  say "  atau tambahkan ke crontab:"
  say "    * * * * * bash $AR/rules-guard.sh >/dev/null 2>&1"
fi

# ============================================================
hr "7. verifikasi"
# ============================================================
if [ "$DRY" = 0 ]; then
  M="$(sha256sum "$AR/operator.AGENTS.md.master" | cut -d' ' -f1)"
  ok=0; bad=0
  for p in "$HOME/AGENTS.md" "$HOME/.config/opencode/AGENTS.md" "$HOME/.pi/agent/AGENTS.md" \
           "$FP/agent/AGENTS.md" "$FP/agent/APPEND_SYSTEM.md"; do
    [ -e "$p" ] || continue
    h="$(sha256sum "$p" 2>/dev/null | cut -d' ' -f1)"
    if [ "$h" = "$M" ]; then ok=$((ok+1)); else bad=$((bad+1)); say "  BEDA: ${p#$HOME/}"; fi
  done
  say "  aturan identik : $ok file"
  say "  aturan beda    : $bad file"
  say "  skills         : $(ls -1A "$AR/skills" | wc -l) entri / $(find "$AR/skills" -name SKILL.md 2>/dev/null | wc -l) SKILL.md"
  say "  protected      : $(wc -l < "$AR/protected/PROTECTED.sha256" 2>/dev/null || echo 0) entri"
  say "  master sha     : ${M:0:16}"
  if [ "$RULES_ONLY" = 0 ]; then
    say "  rg             : $("$FP/agent/bin/rg" --version 2>&1 | head -1 || echo 'tidak ada')"
    say "  fd             : $("$FP/agent/bin/fd" --version 2>&1 | head -1 || echo 'tidak ada')"
    say "  pi             : $(bash -lc 'pi --version' 2>&1 | head -1 || echo 'belum ada — npm i -g free-pi-cli')"
  fi
  say ""
  if [ "$bad" = 0 ]; then say "SELESAI — semua aturan identik."; else say "SELESAI dengan $bad perbedaan — cek log di atas."; fi
else
  say "  [dry] verifikasi dilewati"
fi
