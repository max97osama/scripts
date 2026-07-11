---
description: Run crawlrecon.sh (hakrawler + katana + gospider crawl) against a domain
agent: build
---

Confirm $ARGUMENTS is an authorized in-scope target before proceeding. This script needs a crawl depth and a wordlist path — ask the user if not specified (a depth of 2-3 is typical).

Run:
```
./crawlrecon.sh $ARGUMENTS <depth> <wordlist.txt>
```

Read curls.txt and urls.txt afterward. Summarize the crawl scope (how many unique URLs, interesting paths like admin/api/backup patterns).
