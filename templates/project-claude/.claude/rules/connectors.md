---
paths:
  - "services/**/connectors/**"
  - "services/**/integrations/**"
---
# Connectors and outbound calls

- Read-only means a `(method, path-regex)` allowlist in the single request function, pinned by a test. The only POSTs are token minting and documented query jobs.
- Hosts are fixed or chosen from a constant allowlist; vendor redirect/region headers are not followed; pagination links are followed only on the same host and an allowlisted path, with a cap that errors rather than returning a silent partial list.
- Partial lists are refused as data: a coverage test cannot PASS on items it never saw. A 2xx with an embedded error or partial flag is an error; an unreadable source is "unread", not zero.
- Project out personal data (emails, user names, IPs, locations, command text) unless a reviewed test needs it; prefer stable object ids. Whole raw rows never become subjects.
- Secrets: `repr=False`, never logged, sent only to the token endpoint, cached per session. Error envelopes carry status and path only.
- Retry on 429 inside the request, not around the whole walk. Use the shared rate-limit envelope and the shared HTTP/auth helper; do not copy plumbing from the previous connector.
- Timeouts match the service (a 30 s client timeout in front of a 3-minute query API never produces a result on a real account).
- Runbook permissions match what the code calls: nothing granted for an unused tool.
