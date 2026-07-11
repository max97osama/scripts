---
description: Run urlfilter.sh to split urls.txt in the current directory into js.txt, parameters.txt, and cleaned.txt
agent: build
---

This script takes no arguments — it always reads urls.txt from the current directory. Confirm urls.txt exists before running (it's produced by urlrecon, findrecon, or crawlrecon).

Run:
```
./urlfilter.sh
```

Report how many URLs landed in each output file (js.txt, parameters.txt, cleaned.txt) and highlight anything in parameters.txt with unusual parameter names worth testing (redirect, url, next, file, path, id, etc).
