---
description: Run cleanurls.sh (uro-based dedup/cleanup) on a URLs file, in place
agent: build
---

This script edits the given file in place (dedupes and strips junk/static-asset URLs via uro). Confirm you want to overwrite $ARGUMENTS before running, since the original unfiltered content is not kept.

Run:
```
./cleanurls.sh $ARGUMENTS
```

Report the before/after line count.
