# VPS hardening (T04 draft)

Status: DRAFT. Owner executes on VPS (Oracle Cloud, São Paulo, Ubuntu LTS per D24) and ticks each box. Exact OS and PostgreSQL versions pinned here during provisioning (INFRA-01). Source: ARCHITECTURE.md 12.8.

## Access

- [ ] Admin user with sudo, SSH keys only, password and root login disabled, restricted SSH source range if possible.
- [ ] 2FA on provider, GitHub, Cloudflare, Google accounts.
- [ ] `fail2ban` or equivalent installed.

## Firewall

- [ ] Default-deny inbound; SSH open only.
- [ ] No inbound 80/443/8080/5432 on host: public edge is outbound-only Cloudflare Tunnel inside Docker.
- [ ] Outbound TCP 443 and UDP 7844 allowed for `cloudflared`, plus image pulls.
- [ ] PostgreSQL and metrics port never opened.

## Updates

- [ ] Automatic security updates on, reboot policy documented, time sync (chrony).

## Docker and Compose

- [ ] Docker Engine + Compose v2 installed; Docker enabled at boot.
- [ ] `pontual-api` stack has no published ports. `docker compose ps` must show no `PORTS`. API reachable only by `cloudflared` on internal `edge` network.
- [ ] Docker socket and docker group access limited to admin user.
- [ ] Env files `0600` root-owned, or `PONTUAL_ENV_FILE`/`PONTUAL_DB_ENV_FILE` pointing at root-owned files. Tunnel config world-readable `0644`/`0444` or owner uid 65532 owner-read (`PONTUAL_TUNNEL_CONFIG_FILE`); credentials JSON uid 65532 mode `0400` (`PONTUAL_TUNNEL_CREDENTIALS_FILE`). No secret in `compose.yaml` or image layers.
- [ ] `docker compose config` reviewed, healthcheck green. API, migrate, cloudflared run non-root on read-only root fs; db uses writable named volume. See `docs/runbooks/docker.md`.

## Service user and secrets

- [ ] `/etc/pontual/api.env` and `/etc/pontual/db.env` present, root-owned mode `0600`.
- [ ] `/etc/pontual/cloudflared.yml` present, world-readable `0644`/`0444` or owner uid 65532 owner-read; `/etc/pontual/cloudflared_credentials.json` present, uid 65532, mode `0400`.
- [ ] Tunnel credentials never in compose, env examples, git, logs or docs.
- [ ] No `pontual.service` systemd unit and no host Caddy.
- [ ] `/etc/pontual/compose.override.yaml`, if used, root-owned mode `0644`, not group/world-writable, reviewed; only for dedicated/trusted local network.

## Memory hygiene

- [ ] Swap off or encrypted; disk encryption per provider offering (record choice here).

## Cloudflare edge

- [ ] Tunnel config at `/etc/pontual/cloudflared.yml` declares `api-pontual.spotnik.space -> http://api:8080`; no dashboard-managed ingress.
- [ ] DNS for public hostname points at tunnel.
- [ ] Origin accepts no direct web traffic; only tunnel reaches API.

## PostgreSQL

- [ ] Private Docker network only; never published. TLS required on non-localhost, `scram-sha-256`, separate migrator and least-privilege app roles, `log_statement=none`.
- [ ] Exact version pinned here: ________.

## Secrets and backups

- [ ] Nightly `pg_dump` of small tables, `age`-encrypted, copied off-host, 30-day retention; restore drill done (see `docs/runbooks/ops.md`).
- [ ] 6-month rotation scheduled for DB password, env, tunnel token, SSH keys.

## Monitoring

- [ ] External uptime check on `/v1/health` (owner picks service, INFRA-10); disk-full and certificate-expiry alerts.
- [ ] Weekly 10-minute check per `docs/runbooks/ops.md`.