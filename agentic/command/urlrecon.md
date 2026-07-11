---
description: Run urlrecon.sh (gau + waybackurls + paramspider + httpx validation) against a domain
agent: build
---

Confirm $ARGUMENTS is an authorized in-scope target before proceeding. Optionally accepts a subdomains file with -l.

Run:
```
./urlrecon.sh $ARGUMENTS
```
or, if a subdomains file exists:
```
./urlrecon.sh $ARGUMENTS -l subdomains.txt
```

Read urls.txt, js.txt, and parameters.txt afterward. Summarize live URL count and flag parameterized endpoints worth testing further (xss, sqli, open redirect, ssrf indicators).
