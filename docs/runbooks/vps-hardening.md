# VPS hardening (T04 draft)

Status: DRAFT. The owner executes this on the VPS (Oracle Cloud,
São Paulo, Ubuntu LTS per D24) and ticks each box. Exact OS and
PostgreSQL versions get pinned here during provisioning
(INFRA-01). Source of requirements: PLAN.md 12.8.

## Access

- [ ] Admin user with sudo, SSH keys only, password and root login
  disabled, restricted SSH source range if possible.
- [ ] 2FA on the provider, GitHub, Cloudflare, and Google accounts.
- [ ] `fail2ban` or equivalent installed.

## Firewall

- [ ] Default-deny inbound; SSH open; 80/443 open only from
  Cloudflare IP ranges (refresh on a schedule).
- [ ] PostgreSQL and the metrics port never opened.

## Updates

- [ ] Automatic security updates on, reboot policy documented,
  time sync (chrony).

## Service user and sandbox

- [ ] Dedicated non-login `pontual` user, no sudo; app dir
  read-only for it; `/opt/pontual/current` the only writable path.
- [ ] `server/deploy/pontual.service` installed; `deno` symlinked
  at `/usr/local/bin/deno`; `systemd-analyze security pontual`
  reviewed with no high findings.
- [ ] Env file at `/etc/pontual/env`, `0600` root-owned, holding
  `DATABASE_URL` and the other names in `server/.env.example`.

## Memory hygiene

- [ ] Swap off or encrypted; disk encryption per provider
  offering (record the choice here).

## Reverse proxy (Caddy)

- [ ] TLS 1.2+ only, size and timeout limits, no access logs (or
  IP-free format, short retention), error logs only.
- [ ] Cloudflare DNS/proxy on, origin accepts web traffic only
  from Cloudflare.

## PostgreSQL

- [ ] Localhost only, `scram-sha-256`, separate migrator and
  least-privilege app roles, `log_statement=none`.
- [ ] Exact version pinned here: ________.

## Secrets and backups

- [ ] Nightly `pg_dump` of the small tables, `age`-encrypted,
  copied off-host, 30-day retention; restore drill done (see
  docs/runbooks/ops.md).
- [ ] 6-month rotation scheduled for DB password, env, SSH keys.

## Monitoring

- [ ] External uptime check on `/v1/health` (owner picks the
  service, INFRA-10); disk-full and certificate-expiry alerts.
- [ ] Weekly 10-minute check per docs/runbooks/ops.md.