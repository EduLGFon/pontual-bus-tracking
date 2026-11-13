# Security Policy

Supported versions: alpha only (`0.1.0-alpha.N`). No stable release yet.

## Report a vulnerability

Contact the owner privately. Do not open a public issue for security findings. Include: affected version, reproduction steps, impact, and whether personal or location data is involved. The owner follows ARCHITECTURE.md 12.7 (contain with kill switch, assess, fix, notify per LGPD, learn).

## Scope rules (ARCHITECTURE.md 12)

- Clients never connect to PostgreSQL.
- No location at rest: coordinates never go to DB, disk, logs, or metrics.
- No secrets in repo or client bundles.
- One task per PR. Security tests in ARCHITECTURE.md 12.6 block releases.