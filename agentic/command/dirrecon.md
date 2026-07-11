---
description: Run dirrecon.sh (ffuf + dirsearch + gobuster directory brute-forcing) against a domain
agent: build
---

Confirm $ARGUMENTS is an authorized in-scope target before proceeding. This script needs a subdomains file and a wordlist — ask if not specified. It also uses gobuster; if it's not installed, tell the user to add it (go install github.com/OJ/gobuster/v3@latest) or the script will fail on that step.

Run:
```
./dirrecon.sh $ARGUMENTS <subdomains.txt> <wordlist.txt>
```

Read burl.txt afterward. List discovered paths grouped by status code, and flag anything admin/backup/config-like.
