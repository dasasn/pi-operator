# Geo-Blocking Case Study — nactvet.go.tz

**Date:** 2026-06-02
**Target:** nactvet.go.tz (Tanzania government, IP: 41.93.76.9)

## Problem

Target completely unreachable from VPS (203.175.125.144, Singapore/Oracle).
All proxy tiers failed. Only the mail server on a different IP was accessible.

## Diagnostic Pattern

```
Step 1: Test proxy against known-good target
  curl -x PROXY -sk --max-time 10 https://www.google.com/ -o /dev/null -w "%{http_code}"
  → 200 — proxy IS working

Step 2: Test proxy against actual target
  curl -x PROXY -sk --max-time 10 http://TARGET/ -o /dev/null -w "%{http_code}"
  → 000 — target BLOCKS this proxy's AS/network

Step 3: Escalate tier, don't retry same tier with different zones
```

## Tier Results

| Tier | Google | nactvet.go.tz | mail.nactvet.go.tz |
|------|--------|---------------|---------------------|
| Direct VPS | N/A | 000 | 000 |
| 9proxy TZ (3 zones) | 200 | 000 | timeout |
| BrightData web_unlocker3 | N/A | 407 (auth) | N/A |
| Tor (SOCKS5) | 200 | 000 | **200** ✅ |
| K8s pod (Oracle BD) | N/A | 000 | **200** ✅ |

## Key Insight

The main site (41.93.76.9) blocks ALL non-Tanzanian-ISP IPs — including
9proxy TZ exit nodes which are in datacenter ranges that the target filters.
Only the mail server (196.192.79.165, different IP/subnet) was reachable
via Tor and the K8s pod.

## When This Happens

1. **Don't burn time retrying dead tiers.** If Google=200 but target=000 on a tier, move on.
2. **Check subdomain IPs.** mail.* subdomains are often on different servers with different firewall rules.
3. **Roundcube/GMS servers** (mail.*) are high-value — one valid credential gives access to ALL co-hosted domains.
4. **Document in state.json** under `connectivity.blocked: true` with per-tier results.
5. **User-provided credentials may be valid** — you just can't verify them if the CMS is unreachable.

## What Worked (for the mail server)

- Tor SOCKS5: `curl --socks5-hostname 127.0.0.1:9050`
- Roundcube 1.6.x fingerprinting
- 291 .ac.tz co-hosted domains discovered
- LeakRadar returned 0 records (clean target, no breaches)

## What Didn't Work

- All 9proxy TZ zones (3 tested) — target-specific filtering
- BrightData — auth issues with web_unlocker3 zone
- Direct connection from VPS or K8s pod
- Roundcube credential spray (separate auth from CMS)
- Roundcube SQLi/login bypass attempts
