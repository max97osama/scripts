---
description: Run jsrecon.sh (secrets/keys grep across JS files) against a list of JS URLs
agent: build
---

Confirm the target behind $ARGUMENTS is authorized in-scope before proceeding. This script reads js.txt (a list of JS file URLs) by default from the current directory, or a custom input file if given.

Run:
```
./jsrecon.sh js.txt
```

Read Findings.txt afterward. Report any exposed API keys, tokens, or secrets found, with the source URL for each. Treat any live credential as sensitive — do not print full secret values in chat, just note that one was found and where.
