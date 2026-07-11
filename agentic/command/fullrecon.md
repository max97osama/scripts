---
description: Run full recon pipeline against a target
agent: build
---

Confirm $ARGUMENTS is an authorized in-scope target before proceeding.

Run:
```
./fullrecon.sh $ARGUMENTS
```

After it completes, read all generated txt output files in the current directory, summarize key findings (open subdomains, technologies detected, interesting endpoints, potential vuln indicators), and write the summary to recon.summary.$ARGUMENTS.txt
