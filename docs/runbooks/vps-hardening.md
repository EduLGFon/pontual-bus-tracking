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

- [ ] Default-deny inbound; SSH open only.
- [ ] No inbound 80/443/8080/5432 on the host: the public edge is
  the outbound-only Cloudflare Tunnel running inside Docker.
- [ ] Outbound TCP 443 and UDP 7844 allowed for `cloudflared`, plus
  image pulls.
- [ ] PostgreSQL and the metrics port never opened.

## Updates

- [ ] Automatic security updates on, reboot policy documented,
  time sync (chrony).

## Docker and Compose

- [ ] Docker Engine and Compose v2 installed; Docker enabled at boot.
- [ ] The `pontual-api` stack has no published ports. `docker compose ps`
  must show no `PORTS`. The API is reachable only by `cloudflared` on
  the internal `edge` network.
- [ ] Docker socket and docker group access limited to the admin
  user.
- [ ] Env files `0600` and root-owned, or `PONTUAL_ENV_FILE` and
  `PONTUAL_DB_ENV_FILE` pointing at root-owned files. The token file
  is separate: owned by uid 65532, mode `0400` (or
  `PONTUAL_TUNNEL_TOKEN_FILE` pointing at it). No secret in
  `compose.yaml` or image layers.
- [ ] `docker compose config` reviewed, healthcheck green. API,
  migrate and cloudflared run non-root with read-only root filesystems;
  db uses a writable named volume. See `docs/runbooks/docker.md`.

## Service user and secrets

- [ ] `/etc/pontual/api.env` and `/etc/pontual/db.env` present,
  root-owned mode `0600`.
- [ ] `/etc/pontual/tunnel_token` present, owned by uid 65532,
  mode `0400`.
- [ ] Tunnel token never placed in compose, env examples, git, logs
  or documentation.
- [ ] No `pontual.service` systemd unit and no host Caddy.

## Memory hygiene

- [ ] Swap off or encrypted; disk encryption per provider
  offering (record the choice here).

## Cloudflare edge

- [ ] Tunnel `pontual` configured in the Cloudflare dashboard with
  service target `http://api:8080`.
- [ ] DNS for the public hostname points at the tunnel.
- [ ] Origin accepts no direct web traffic; only the tunnel reaches
  the API.

## PostgreSQL

- [ ] Private Docker network only; never published. TLS required
  on non-localhost connections, `scram-sha-256`, separate migrator
  and least-privilege app roles, `log_statement=none`.
- [ ] Exact version pinned here: ________.

## Secrets and backups

- [ ] Nightly `pg_dump` of the small tables, `age`-encrypted,
  copied off-host, 30-day retention; restore drill done (see
  docs/runbooks/ops.md).
- [ ] 6-month rotation scheduled for DB password, env, tunnel
  token, SSH keys.

## Monitoring

- [ ] External uptime check on `/v1/health` (owner picks the
  service, INFRA-10); disk-full and certificate-expiry alerts.
- [ ] Weekly 10-minute check per docs/runbooks/ops.md.
