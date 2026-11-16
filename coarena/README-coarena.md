# Coarena Model API di pi

Base URL: `https://coarena.ai/api/v1` (OpenAI-compatible: `/chat/completions`, `/models`, `/feedback`).

## File

| Path | Isi |
|---|---|
| `~/.pi/agent/models.json` | provider `coarena`, 20 model, api `openai-completions`, `apiKey: ${COARENA_API_KEY}` |
| `~/.pi/agent/.env` | `COARENA_API_KEY=...` (chmod 600) |
| `~/.pi/agent/extensions/coarena-feedback.ts` | tangkap `x-coarena-request-id` + rating feedback |

## Pakai

```bash
set -a; . ~/.pi/agent/.env; set +a
export PI_CODING_AGENT_DIR=~/.pi/agent      # agar models.json + extension terbaca
pi --model coarena/kimi-k3-1-pro
```

Di dalam sesi:

- `/model` → cari `coarena` (20 model: claude-*, gpt-6-*, gemini-*, grok-4-7, kimi-k3-1-pro,
  minimax-m3-1-flash, glm-5-3-flash, hy4, mimo-v2-6-pro, deepseek-v4-1-flash-1017).
- `/coarena-models` — list model dari API.
- `/coarena-last` — request_id yang menunggu rating.
- `/coarena-rate up|down|none [catatan]` — kirim `POST /api/v1/feedback`.
- `Ctrl+Alt+U` / `Ctrl+Alt+D` — rating cepat untuk balasan terakhir.

## Catatan operasional

- Coarena menyimpan semua prompt dan balasan yang lewat Model API dan dapat memakainya,
  termasuk dataset yang dilisensikan — tercantum di `GET /api/v1/usage` (`terms.points`).
  Jangan kirim data pribadi sensitif. `.env` di sini memakai key yang sama.
- `pi` di mesin ini adalah symlink ke `free-pi-cli`; binary itu tidak punya flag
  `--list-models`/`--extension`. Konfigurasi di atas dipakai oleh runtime pi/SDK
  (`PI_CODING_AGENT_DIR`) dan telah diverifikasi lewat `createAgentSession`.
- Rate limit per model dikirim lewat header `x-ratelimit-*`; model yang diminta bisa
  disubstitusi (`x-coarena-substituted-from/to`).
