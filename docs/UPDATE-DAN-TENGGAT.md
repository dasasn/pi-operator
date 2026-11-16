# Kalau tidak di-update, apa yang rusak?

Diukur di WSL, 2026-11-16. Bukan teori.

---

## Jawaban singkat

**Model tidak mati karena versi lama.** Yang bikin mati ada tiga hal lain:

| Yang bikin mati | Tenggat | Kalau lewat |
|---|---|---|
| **Token login** | 90 hari (exp `2027-02-14`) | semua model berhenti, `pi` minta login ulang |
| **Server model lokal** `127.0.0.1:7778` | kapan saja | 2 model lokal hilang, sisanya jalan |
| **Patch bundle hilang** | saat `npm update` | model lokal tidak bisa dipilih, jatuh ke model online yang menolak |

Versi `free-pi-cli` sendiri **bukan** penyebab. Yang terpasang 0.6.21, npm terbaru
0.6.22. Selisih satu patch, dan tidak ada mekanisme yang memaksa update.

---

## 1. Token: ini yang benar-benar punya tenggat

```
iat : 2026-11-16T06:14:17Z
exp : 2027-02-14T06:14:17Z
sisa: 90 hari
```

Artinya: **sampai 14 Februari 2027** semuanya jalan tanpa disentuh. Setelah itu
token kedaluwarsa dan semua model berhenti, bukan cuma yang lokal.

Cara cek kapan saja:

```bash
node -e "
const d=require(process.env.HOME+'/.free-pi/agent/credentials.json');
const j=JSON.parse(Buffer.from(d.token.split('.')[1],'base64url').toString());
console.log('exp:', new Date(j.exp*1000).toISOString());
console.log('sisa:', Math.round((j.exp*1000-Date.now())/86400000), 'hari');
"
```

Kalau sudah lewat: `pi --device-login`.

---

## 2. Server model lokal: mati kalau tidak dinyalakan

`models.json` menunjuk `http://127.0.0.1:7778/v1`. Dua model di sana:

- `deepseek-v4.1-flash-1017-heretic` — "bitllm local deepseek (uncensored)"
- `junmo-k/GLM-5.3-Flash-FP4-Local-Piecrust-Abliterated-MLX` — "bitllm local GLM (abliterated)"

Server itu **proses**, bukan file. Kalau mesin reboot atau servernya mati, dua model
itu hilang dari daftar. Model lain (online) tetap jalan.

Cek:

```bash
curl -s -m 3 http://127.0.0.1:7778/v1/models | head -c 100
```

Kosong = server mati. Ini yang paling sering terasa seperti "modelnya tidak jalan".

---

## 3. Patch bundle: rusak kalau `npm update` tanpa pikir

Ini bagian yang paling perlu Anda tahu.

Bundle `main-7sxf1v5b.js` punya 3 penanda yang harus ada:

```
__PI_LOCAL_DEFENSE__   ADA
PI_LOCAL_ALLOW         ADA
operator-gate.md       ADA
```

`bundle-patch.cjs` menambal `buildSettingsManager`, `decideToolCall`,
`earlyReturn`, `patch`, `post` — intinya: memaksa model lokal (section=defense)
bisa dipilih, dan aturan operator ikut terbaca.

Kalau Anda `npm install -g free-pi-cli@latest`:

1. npm menaruh bundle baru di `dist/`
2. `maint.sh` mendeteksi pin lama tidak valid, lalu **rebuild dari paket baru**
3. rebuild itu menjalankan `bundle-patch.cjs` lagi

Jadi **selama patcher masih cocok dengan struktur bundle baru**, update aman.
Kalau struktur bundle berubah (versi mayor), patcher bisa gagal → pin lama
dipertahankan, tapi tidak ter-patch → model lokal tidak bisa dipilih.

Log yang menandakan ini:

```bash
tail -20 ~/.free-pi/state/maint.log
# "pinned bundle REBUILT dari ..."        -> update berhasil
# "pinned bundle rusak dan gagal dibangun ulang"  -> JANGAN lanjut, balikin
```

---

## 4. Yang TIDAK rusak kalau tidak di-update

- Aturan operator — dijaga `rules-guard.timer` tiap 60 detik
- Skill — symlink ke `~/.agent-rules/skills`, tidak ikut update
- `operator-gate.md`, `mcp.json`, `models.json`, `rg`, `fd` — sekarang dijaga
  langkah 9 guard (baru dipasang hari ini)
- Sesi lama — tidak disentuh

---

## 5. Prosedur update yang aman

### Kalau cuma mau aman (rekomendasi)

Tidak usah update apa pun. Cek token tiap bulan:

```bash
# tambahkan ke ~/.bashrc atau cron bulanan
node -e "
const d=require(process.env.HOME+'/.free-pi/agent/credentials.json');
const j=JSON.parse(Buffer.from(d.token.split('.')[1],'base64url').toString());
const s=Math.round((j.exp*1000-Date.now())/86400000);
if(s<14) console.log('TOKEN MAU HABIS:', s, 'hari — jalankan: pi --device-login');
else console.log('token ok,', s, 'hari lagi');
"
```

### Kalau mau update pi

Urutannya penting. Jangan lompat.

```bash
# 1. backup dulu
cp -a ~/.free-pi/state/pinned ~/.free-pi/state/pinned.bak-$(date +%Y%m%d)
cp -a ~/.free-pi/agent ~/.free-pi/agent.bak-$(date +%Y%m%d)

# 2. catat versi sekarang
pi --version
sha256sum ~/.free-pi/state/pinned/main-7sxf1v5b.js

# 3. update
npm install -g free-pi-cli@latest

# 4. paksa maint.sh jalan (jangan tunggu timer)
bash ~/.free-pi/state/maint.sh

# 5. cek hasil
pi --version
sha256sum ~/.free-pi/state/pinned/main-7sxf1v5b.js
tail -5 ~/.free-pi/state/maint.log
```

**Lulus kalau:**
- `pi --version` naik
- `maint.log` ada `pinned bundle REBUILT` atau `pinned bundle ok`
- `pi` bisa pilih model lokal

**Gagal kalau:**
- `maint.log` ada `gagal dibangun ulang`
- model lokal hilang dari daftar

### Kalau gagal, balikin

```bash
cp -f ~/.free-pi/state/pinned.bak-YYYYMMDD/main-7sxf1v5b.js ~/.free-pi/state/pinned/
bash ~/.agent-rules/rules-guard.sh
pi --version
```

Kalau masih gagal, turunkan versi:

```bash
npm install -g free-pi-cli@0.6.21
cp -f ~/.free-pi/state/pinned.bak-YYYYMMDD/main-7sxf1v5b.js ~/.free-pi/state/pinned/
```

---

## 6. Yang saya perbaiki hari ini

Tiga celah yang bikin update bisa merusak tanpa ketahuan:

| Celah | Akibat | Perbaikan |
|---|---|---|
| `pi-maintenance.service` panggil `bundle-patch.py` | error tiap 2 menit, patcher tidak pernah jalan | diganti ke `bundle-patch.cjs` |
| Guard tidak jaga `operator-gate.md`, `mcp.json`, `models.json`, `rg`, `fd` | update menimpa, aturan/model hilang | langkah 9 + mirror di `~/.agent-rules/protected/` |
| Tidak ada salinan kanonik file itu | tidak bisa dipulihkan | `PROTECTED.sha256` 6 entri |

Sudah diuji dengan sengaja merusak keempat file, guard memulihkan semuanya:

```
RESTORED protected ./agent/mcp.json
RESTORED protected ./agent/models.json
RESTORED protected ./agent/operator-gate.md
RESTORED protected ./bin/rg
```

---

## 7. Ringkas: apa yang harus dilakukan berkala

| Interval | Yang dicek | Perintah |
|---|---|---|
| tiap bulan | token masih > 14 hari | script di bagian 5 |
| tiap reboot | server `:7778` hidup | `curl -s -m 3 http://127.0.0.1:7778/v1/models` |
| tiap mau update | backup pinned + agent | `cp -a` di bagian 5 |
| tiap update | `maint.log` tidak ada "gagal" | `tail -5 ~/.free-pi/state/maint.log` |
| kapan saja | aturan masih utuh | `bash ~/.agent-rules/rules-guard.sh` |

Tidak ada satupun dari ini yang butuh update versi. Yang punya tenggat cuma token.
