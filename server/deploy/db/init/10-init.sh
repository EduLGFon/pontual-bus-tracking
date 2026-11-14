#!/bin/sh
# First-start initialization for the project PostgreSQL container.
#
# Runs once, as the postgres OS user, after initdb and before the final server
# starts. It generates a self-signed TLS certificate, requires TLS for every
# TCP connection, and creates the least-privilege application role.
# Passwords come only from the environment; nothing secret is written to the
# image. See DECISIONS.md D101 and docs/runbooks/docker.md.
set -eu

: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${PONTUAL_APP_PASSWORD:?PONTUAL_APP_PASSWORD is required}"

tls_dir="$PGDATA/tls"
mkdir -p "$tls_dir"
chmod 700 "$tls_dir"

# The certificate is internal to the Docker network. Clients encrypt but do
# not verify it (postgres.js maps sslmode=require to rejectUnauthorized:false).
openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
  -keyout "$tls_dir/server.key" \
  -out "$tls_dir/server.crt" \
  -subj "/CN=pontual-db" >/dev/null 2>&1
chmod 600 "$tls_dir/server.key"
chmod 644 "$tls_dir/server.crt"

cat >> "$PGDATA/postgresql.conf" <<EOF
# Managed by server/deploy/db/init/10-init.sh.
ssl = on
ssl_cert_file = '$tls_dir/server.crt'
ssl_key_file = '$tls_dir/server.key'
ssl_min_protocol_version = 'TLSv1.2'
EOF

# Reject cleartext TCP; the Unix socket stays available inside the container.
sed -i 's/^host[[:space:]]/hostssl /' "$PGDATA/pg_hba.conf"

# pgcrypto and the four base tables arrive with migration 0001. Create the
# role first so the migration's password-less `create role ... if not exists`
# is a no-op, then set the password from the environment. format(%L) and the
# psql variables keep the password out of SQL string concatenation.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=app_password="$PONTUAL_APP_PASSWORD" \
  --set=db_name="$POSTGRES_DB" <<'SQL'
select format('create role pontual_app with login password %L', :'app_password')
where not exists (select 1 from pg_roles where rolname = 'pontual_app')\gexec
select format('alter role pontual_app with login password %L', :'app_password')\gexec
revoke connect on database :"db_name" from public;
grant connect on database :"db_name" to pontual_app;
grant usage on schema public to pontual_app;
SQL
