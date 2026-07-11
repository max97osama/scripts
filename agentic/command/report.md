---
description: Compile a full bug report from validated findings
agent: build
---

Read all poc.*.$ARGUMENTS.txt and recon.summary.$ARGUMENTS.txt files in the current directory.

Write a full bug report to report.$ARGUMENTS.txt containing:
- Title
- Severity (CVSS-style estimate)
- Affected asset/endpoint
- Description
- Steps to reproduce
- Proof of concept
- Impact
- Suggested remediation

Only include findings that were explicitly validated, not raw scan output.
