# pi-operator

Aturan operator + 100 skill + config free-pi, dengan installer yang jalan di
**Ubuntu/Debian, Linux lain, macOS, dan Termux (Android)**.

Tujuannya satu: bikin semua agent di mesin mana pun membaca aturan yang sama
persis, dan menjaga agar tetap sama setelah `pi` di-update.

---

## Isi repo

```
rules/
  operator.AGENTS.md.master    aturan induk (sumber tunggal)
  rules-guard.sh               penyelaras + pemulih, jalan tiap 60 detik
  skills/                      100 skill (85 dengan SKILL.md)
  protected/                   file yang tidak boleh ditimpa update
config/free-pi/
  agent/                       operator-gate.md, models.json, mcp.json, extensions
  state/                       maint.sh, pinned bundle, patcher
coarena/                       extension coarena + models (tanpa API key)
scripts/
  detect-platform.sh           deteksi linux/darwin/android + arsitektur
  install-tools.sh             pasang rg & fd sesuai platform
install.sh                     installer utama
```

---

## Install cepat

```bash
git clone <URL-REPO> pi-operator
cd pi-operator
npm install -g free-pi-cli
bash install.sh
pi --device-login
```

Panduan lengkap per platform, termasuk semua masalah yang sering muncul:
**[docs/INSTALL-UBUNTU-TERMUX.md](docs/INSTALL-UBUNTU-TERMUX.md)**

---

## Kenapa ada `scripts/install-tools.sh`

`rg` dan `fd` adalah binary native. Binary x86-64 tidak jalan di Termux
(aarch64), dan binary glibc tidak jalan di Alpine (musl). Karena itu binary
**tidak** disimpan di repo. Installer mendeteksi platform lalu:

| Platform | Cara pasang |
|---|---|
| Linux x86_64 | unduh `x86_64-unknown-linux-musl` |
| Linux aarch64 | unduh `aarch64-unknown-linux-gnu` |
| Termux (android-aarch64) | `pkg install ripgrep fd` |
| macOS | `brew install ripgrep fd` |

---

## Cara kerja penjagaan

Tiga lapis, semuanya otomatis:

1. **`rules-guard.sh`** — tiap 60 detik membandingkan hash semua jalur aturan
   dengan master. Beda sedikit, langsung dipulihkan. Juga memulihkan file di
   `protected/` kalau hilang atau berubah.
2. **`maint.sh`** — menjaga bundle `pi` tetap ter-patch. Kalau `npm update`
   merusak patch, dia membangun ulang dari paket terpasang.
3. **`protected/PROTECTED.sha256`** — checksum kanonik untuk `operator-gate.md`,
   `mcp.json`, `models.json`, `default-model.json`.

Jadwal guard:

- Linux dengan systemd: `rules-guard.timer`, tiap 60 detik
- Termux: hook `~/.bashrc`, jalan saat sesi dibuka lalu loop di latar belakang
- Tanpa keduanya: crontab

---

## Verifikasi setelah install

```bash
bash ~/.agent-rules/rules-guard.sh
ls -1A ~/.agent-rules/skills | wc -l      # 100
~/.free-pi/agent/bin/rg --version
~/.free-pi/agent/bin/fd --version
pi --version
```

---

## Yang tidak disertakan

- **API key Coarena** — isi sendiri di `~/.pi/agent/.env`
- **Binary `rg`/`fd`** — dipasang per platform
- **Token login** — `pi --device-login`
- **Server model lokal** `127.0.0.1:7778` — itu proses terpisah, bukan file
