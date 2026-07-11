---
description: Run smugglerrecon.sh (HTTP request smuggling checks) against a domain or subdomains file
agent: build
---

Confirm $ARGUMENTS is an authorized in-scope target before proceeding. HTTP smuggling checks can affect other users' traffic on shared infrastructure — be extra careful this is in scope and rate limits are respected (the script already sleeps 8s between requests, don't remove that).

Run:
```
./smugglerrecon.sh $ARGUMENTS
```

Read smugglerreport.txt afterward. For any CL.TE/TE.CL/TE.TE finding, treat it as high severity and validate carefully before drafting a PoC to poc.smuggling.$ARGUMENTS.txt
