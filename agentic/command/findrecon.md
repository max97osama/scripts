---
description: Run findrecon.sh (assetfinder + linkfinder + secretfinder + xnLinkFinder + urlfinder) against a domain
agent: build
---

Confirm $ARGUMENTS is an authorized in-scope target before proceeding.

Run:
```
./findrecon.sh $ARGUMENTS
```

Read findurls.txt and urls.txt afterward. Flag any secrets/tokens found by secretfinder (don't print full values, just note one was found and where) and summarize the breadth of discovered URLs.
