---
description: Run SQL injection discovery recon against a target
agent: build
---

Confirm $ARGUMENTS is an authorized in-scope target before proceeding.

Run:
```
./sqlrecon.sh $ARGUMENTS
```

Read the output. For each candidate injection point, validate carefully (non-destructive checks only) before treating it as confirmed. Draft a PoC only for confirmed findings and write it to poc.sqli.$ARGUMENTS.txt
