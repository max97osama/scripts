---
description: Run hunter.sh (nuclei scan with exposure/vuln/cve/misconfig/takeover tags) against a subdomain list
agent: build
---

Confirm the domain and target list behind $ARGUMENTS are authorized in-scope before proceeding. This script requires -d <domain> -l <subdomain_list> -o <output_file> and updates nuclei templates on every run (can be slow on first use).

Run:
```
./hunter.sh -d <domain> -l <subdomain_list> -o nuclei.$ARGUMENTS.txt
```

Read the output file afterward. Group findings by severity (critical/high first) and summarize each with the template name and affected URL. Flag anything tagged takeover or default-login as high priority.
