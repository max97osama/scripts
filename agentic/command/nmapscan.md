---
description: Run nmapscan.sh (full port + vuln script scan) against a target IP or domain
agent: build
---

Confirm $ARGUMENTS is an authorized in-scope target before proceeding.

Note: this scans all 65535 ports with vuln scripts (-p- -sV -sC --script vuln) at a conservative rate (-T2), which can take a long time and is CPU-heavy. On this VM's limited resources, expect this to run slowly — let it finish in the background rather than running multiple scans in parallel.

Run:
```
./nmapscan.sh $ARGUMENTS
```

Read nmapreport.txt afterward. Summarize any flagged vulnerabilities, open ports of interest, and service versions that look outdated.
