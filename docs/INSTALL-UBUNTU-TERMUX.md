# Cara install — Ubuntu/Debian, Linux lain, dan Termux

Repo: `pi-operator`. Isinya aturan operator, 100 skill, config free-pi, dan
script installer yang mendeteksi platform sendiri.

Yang **tidak** ada di repo: `rg` dan `fd` binary. Itu dipasang oleh
`scripts/install-tools.sh` sesuai arsitektur mesin Anda, karena binary x86-64
tidak akan jalan di Termux (aarch64).

---

## Bagian 1 — Ubuntu / Debian

### 1.1 Prasyarat

```bash
sudo apt update
sudo apt install -y git curl ca-certificates build-essential
```

Node.js **v22 atau lebih baru** (v20 DITOLAK oleh free-pi-cli). Pakai NodeSource, jangan paket `nodejs` bawaan Ubuntu
(terlalu tua):

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
node -v      # harus v22.x — v20 ditolak free-pi-cli
npm -v
```

### 1.2 Clone repo

```bash
mkdir -p ~/src
cd ~/src
git clone <URL-REPO> pi-operator
cd pi-operator
```

### 1.3 Pasang free-pi

```bash
npm install -g free-pi-cli
pi --version
```

### 1.4 Jalankan installer

```bash
bash install.sh --dry-run     # lihat rencana dulu
bash install.sh               # pasang
```

Yang dilakukan installer:

1. `~/.agent-rules/` — master aturan + 100 skill + `protected/`
2. `~/AGENTS.md` (perm 444) dan symlink ke `.config/opencode`, `.pi/agent`
3. `~/.free-pi/agent/` — `operator-gate.md`, `models.json`, `mcp.json`, extensions
4. `~/.free-pi/state/` — `maint.sh`, `pinned/`, patcher
5. `rg` + `fd` sesuai platform
6. `rules-guard.timer` systemd (kalau systemd ada)
7. Verifikasi checksum semua jalur aturan

### 1.5 Login

```bash
pi --device-login
```

Ikuti URL yang muncul. Token berlaku 90 hari.

### 1.6 Verifikasi

```bash
bash ~/.agent-rules/rules-guard.sh
ls -1A ~/.agent-rules/skills | wc -l          # harus 100
~/.free-pi/agent/bin/rg --version             # ripgrep
~/.free-pi/agent/bin/fd --version             # fd
systemctl --user is-active rules-guard.timer  # active
pi --version
```

### 1.7 Kalau systemd tidak ada (container, WSL1)

Installer otomatis jatuh ke mode manual. Tambahkan ke crontab:

```bash
( crontab -l 2>/dev/null; echo "* * * * * bash $HOME/.agent-rules/rules-guard.sh >/dev/null 2>&1" ) | crontab -
```

---

## Bagian 2 — Termux (Android)

Ini yang paling banyak beda. Baca sampai habis sebelum mulai.

### 2.1 Pasang Termux yang benar

**Jangan dari Google Play.** Versi Play sudah tidak dirawat dan `pkg` rusak.

Ambil dari F-Droid: <https://f-droid.org/packages/com.termux/>

Atau GitHub release: <https://github.com/termux/termux-app/releases>

### 2.2 Update paket

```bash
pkg update -y
pkg upgrade -y
```

### 2.3 Prasyarat

```bash
pkg install -y git nodejs-lts curl ripgrep fd
```

Catatan penting:

- Paket Node di Termux bernama **`nodejs-lts` (v22)**, bukan `nodejs`
- `ripgrep` dan `fd` **harus** dari `pkg`, bukan binary unduhan. Binary
  glibc/musl x86-64 tidak jalan di Android aarch64
- Jangan pakai `npm install -g` untuk paket yang butuh `node-gyp` — sering gagal
  di Termux karena tidak ada toolchain lengkap

Cek:

```bash
node -v          # v22.x atau lebih — v20 ditolak
rg --version
fd --version
```

### 2.4 Clone repo

```bash
mkdir -p ~/src
cd ~/src
git clone <URL-REPO> pi-operator
cd pi-operator
```

### 2.5 Pasang free-pi

```bash
npm install -g free-pi-cli
pi --version
```

Kalau gagal karena permission, arahkan prefix ke home:

```bash
npm config set prefix ~/.npm-global
echo 'export PATH=$HOME/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
npm install -g free-pi-cli
```

### 2.6 Jalankan installer

```bash
bash install.sh --dry-run
bash install.sh
```

Installer mendeteksi Termux lewat `$PREFIX` dan otomatis:

- memakai `pkg install ripgrep fd` (bukan unduh binary)
- membuat symlink `rg`/`fd` dari `$PREFIX/bin` ke `~/.free-pi/agent/bin`
- **tidak** memakai systemd (Termux tidak punya), ganti dengan hook `~/.bashrc`

### 2.7 Guard di Termux

Termux tidak punya systemd, jadi guard jalan lewat hook shell. Installer
menambahkan blok ini ke `~/.bashrc`:

```bash
# rules-guard-hook: jalankan guard tiap 60 detik di latar belakang
if [ -x "$HOME/.agent-rules/rules-guard.sh" ]; then
  if [ ! -f "$HOME/.agent-rules/.guard.pid" ] || ! kill -0 "$(cat "$HOME/.agent-rules/.guard.pid" 2>/dev/null)" 2>/dev/null; then
    ( while true; do bash "$HOME/.agent-rules/rules-guard.sh" >/dev/null 2>&1; sleep 60; done & echo $! > "$HOME/.agent-rules/.guard.pid" )
  fi
fi
```

Artinya guard jalan **saat Anda membuka sesi Termux**, lalu terus di latar
belakang selama Termux hidup. Kalau Termux dimatikan Android, guard berhenti.
Itu batasan platform, bukan bug.

Kalau mau guard jalan tiap login saja (tanpa loop):

```bash
echo 'bash ~/.agent-rules/rules-guard.sh >/dev/null 2>&1' >> ~/.bashrc
```

### 2.8 Login

```bash
pi --device-login
```

### 2.9 Verifikasi

```bash
bash ~/.agent-rules/rules-guard.sh
ls -1A ~/.agent-rules/skills | wc -l     # 100
~/.free-pi/agent/bin/rg --version
~/.free-pi/agent/bin/fd --version
pi --version
```

---

## Bagian 3 — Masalah yang sering muncul

| Gejala | Sebab | Perbaikan |
|---|---|---|
| `pkg: command not found` | Termux dari Play Store | pasang dari F-Droid |
| `rg: cannot execute binary file` | binary x86-64 di Android | `pkg install ripgrep`, jalankan ulang installer |
| `npm ERR! EACCES` | prefix global tidak bisa ditulis | `npm config set prefix ~/.npm-global` |
| `pi: command not found` | PATH belum dimuat | `source ~/.bashrc`, cek `~/.npm-global/bin` |
| `rules-guard.timer` tidak ada | tidak ada systemd | pakai crontab (Linux) atau hook `.bashrc` (Termux) |
| `AGENTS.md` berubah sendiri | guard bekerja, itu memang tugasnya | cek `~/.agent-rules/guard.log` |
| model lokal tidak muncul | server `127.0.0.1:7778` mati | nyalakan servernya, atau pakai model online |
| `pi` minta login terus | token kedaluwarsa | `pi --device-login` |

---

## Bagian 4 — Update

Aturan dan skill tidak perlu di-update; guard yang menjaga. Yang punya tenggat
hanya token (90 hari).

Kalau mau update `free-pi-cli`:

```bash
cp -a ~/.free-pi/state/pinned ~/.free-pi/state/pinned.bak-$(date +%Y%m%d)
npm install -g free-pi-cli@latest
bash ~/.free-pi/state/maint.sh
tail -5 ~/.free-pi/state/maint.log
```

Lulus kalau log berisi `pinned bundle REBUILT` atau `pinned bundle ok`.
Gagal kalau `gagal dibangun ulang` — balikin dari `pinned.bak`.

Detail lengkap: `UPDATE-DAN-TENGGAT.md`.

---

## Bagian 5 — Ringkasan perintah per platform

| Langkah | Ubuntu/Debian | Termux |
|---|---|---|
| prasyarat | `apt install git curl build-essential` | `pkg install git curl` |
| node | NodeSource setup_22.x | `pkg install nodejs-lts` |
| rg/fd | otomatis (unduh binary) | `pkg install ripgrep fd` |
| free-pi | `npm i -g free-pi-cli` | `npm i -g free-pi-cli` |
| installer | `bash install.sh` | `bash install.sh` |
| jadwal guard | systemd timer | hook `.bashrc` |
| login | `pi --device-login` | `pi --device-login` |
