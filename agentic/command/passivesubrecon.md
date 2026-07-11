---
description: Run apirecon.sh (kiterunner + arjun + qsreplace + open-redirect checks) against a domain
agent: build
---

Confirm $ARGUMENTS is an authorized in-scope target before proceeding.

This script needs a domain, a subdomains file, and a kiterunner wordlist. If you don't have the subdomains file or wordlist path, ask the user for them before running.

Run:
```
./apirecon.sh <domain> <subdomains.txt> <kite_wordlist>
```

Read report.txt and vulnerable_urls.txt afterward. Summarize interesting API endpoints, exposed methods, and any parameter injection or open-redirect leads. Validate before calling anything confirmed.
