---
description: Run commixrecon.sh (command injection testing via commix) against a list of parameterized URLs
agent: build
---

Confirm the target domain(s) behind $ARGUMENTS are authorized in-scope before proceeding. This script requires a parameters.txt file of URLs with parameters (e.g. produced by urlfilter or urlrecon) — check it exists first, or generate it.

Run:
```
./commixrecon.sh parameters.txt
```

Read cmdireport.txt afterward. For each finding, validate manually before treating it as confirmed, then draft a PoC to poc.commix.$ARGUMENTS.txt
