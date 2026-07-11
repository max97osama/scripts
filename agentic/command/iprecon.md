---
description: Run iprecon.sh (origin IP discovery behind Cloudflare) against a subdomains file
agent: build
---

Confirm the target behind $ARGUMENTS is authorized in-scope before proceeding. This script requires a subdomains.txt file — check it exists first.

Run:
```
./iprecon.sh subdomains.txt
```

Read activesubs.txt and ips.txt afterward. Summarize which subdomains are alive and list any non-Cloudflare (origin) IPs found — these are often high-value findings since they can bypass WAF/CDN protection.
