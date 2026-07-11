---
description: Run XSS discovery recon against a target
agent: build
---

Confirm $ARGUMENTS is an authorized in-scope target before proceeding.

Run:
```
./xssrecon.sh $ARGUMENTS
```

Read the output. For each candidate reflected/DOM XSS point, validate it manually with curl/dalfox before treating it as confirmed. Draft a PoC only for confirmed findings and write it to poc.xss.$ARGUMENTS.txt
