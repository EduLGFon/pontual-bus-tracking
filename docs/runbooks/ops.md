# Runbooks de operação (T50)

Rotina semanal de 10 minutos: CPU/RAM/disco/conexões e latência do
banco no VPS, histórico do monitor de uptime, analíticos Cloudflare
(sem dados pessoais), vitais da Play (crashes/ANR), alertas do
Dependabot, atualizações de segurança pendentes, sucesso do backup.

Sem dados pessoais em tíquetes, logs de incidente ou comandos
colados: nunca coordenadas, tokens, sessões ou ids de aparelho.

## Kill switch (abuso, bug, incidente)

1. `update app_config set value='false' where key='service_enabled';`
   Vale em ~30 s: starts e pings passam a `503 maint`.
2. Opcional: `config.json` com `maintenance=true` e redeploy do
   estático; clientes mostram S13.
3. Confira: `curl /v1/health` e um start de teste (espera 503).
4. Investigue; para voltar, apague a chave ou volte a `true`.

## Sinalizações de passageiros (D82)

- Desligar só as sinalizações:
  `update app_config set value='false' where key='reports_enabled';`.
  Escritas passam a `503 maint` e o próximo snapshot manda `r: []`, o
  que limpa os chips nos clientes. Nada é gravado em disco.
- Um reinício da API apaga todas as sinalizações em memória. Isso é
  esperado; não há histórico para recuperar. A célula de ~150 m é o
  único alvo guardado; coordenadas exatas nunca chegam ao servidor.
- Tetos: `reports_max_per_line` (8) e `reports_max_total` (2000).
  TTLs e idade máxima ficam nas chaves `reports_ttl_*` e
  `reports_max_age_*`.

## API fora do ar ou reiniciando (alerta, `502/503`)

1. `systemctl status pontual`, `journalctl -u pontual` (sem PII).
2. Reinicie o serviço; se for release ruim, faça rollback (simetria
   em `server/deploy`, tag anterior) e confira `/v1/health`.
3. Clientes retomam sozinhos em um intervalo de ping (KL6).

## Banco fora do ar (`/v1/health` degradado)

1. Serviço PostgreSQL, espaço em disco, conexões.
2. A API segue servindo leituras e viagens ativas da memória, mas
   recusa registro e consentimento.
3. Restaure do backup só se houver perda de dados.

## Disco cheio / carga alta

1. Ache a causa (logs, backups), rode ou limpe, suba limites.
2. Temporário: baixe `max_active_trips` ou suba
   `follower_interval_s` / `leader_interval_moving_s` via
   `app_config`.

## Certificado / Cloudflare (erros TLS)

1. Modo SSL, certificado de origem, Caddy, DNS.
2. Volte à última configuração boa conhecida.
3. Diagnóstico de hostname: `openssl s_client -connect <host>:443
   -servername <host>`. Falha de handshake em subdomínio de segundo
   nível indica falta de certificado, não problema no túnel.

## Domínios e certificados (INFRA-05)

- App: `pontual.spotnik.space` no GitHub Pages. O CNAME na Cloudflare
  precisa ser DNS only (nuvem cinza). Com o proxy laranja o GitHub não
  emite o certificado do domínio customizado.
- API: `api-pontual.spotnik.space` pelo túnel `pontual`. É host de
  primeiro nível e o Universal SSL cobre.
- `api.pontual.spotnik.space` é segundo nível: o Universal SSL não cobre
  e o Total TLS não emite para hostnames do Tunnel. Só funciona com
  Advanced Certificate Manager (US$ 10/mês) e certificado avançado.
- Depois de mudar `API_ORIGIN`, rode o workflow `deploy-static` de novo.
  Variável alterada não rebuilda sozinha. Valor atual:
  `API_ORIGIN=https://api-pontual.spotnik.space`.
  `STATIC_ORIGIN` é opcional: sem ela, o workflow lê o domínio customizado
  do Pages e usa `https://pontual.spotnik.space`.
- Enquanto a API estiver em easy-test (`APP_ENV=local` com
  `TEST_EASY_PUBLISH=true`), o PWA pode ser rebuildado com
  `FIX_ACCURACY_MAX_M=500` e `FORCE_PING_BUTTON=true` nas variáveis do
  repositório. Os padrões são 60 e false. Remova as duas e rode
  `deploy-static` antes do piloto: o PWA é público e, com easy-publish,
  qualquer visitante pode publicar um ônibus parado.

## Ônibus fantasma / falsificação

1. Identifique pelo SQL em `devices` e métricas (sem coordenadas
   no tíquete); adicione o aparelho a `blocked_devices`.
2. Aperte bbox/rota na config; a viagem cai no próximo ping.

## Rotação de segredos (suspeita ou 6 meses)

Senha do banco, env, SSH, tokens Cloudflare/GitHub; reinicie a
API; reemita tokens só se hashes vazaram (apague linhas de
`devices`, clientes registram de novo).

## Release ruim no app (pico de crash)

Pause a distribuição na Play, reverta dado estático se preciso,
kill switch se for servidor.

## Backup e restore (antes do fim do alpha, depois trimestral)

Restaure o último dump cifrado num banco de rascunho, confira
contagens, anote o tempo.

## Pedido de titular (e-mail recebido)

Confira o pedido, oriente "Apagar meus dados" ou apague pelo
código de suporte em `devices`, responda no prazo legal,
registre sem dados pessoais.

## Incidente (PLAN 12.7)

Conter, avaliar, corrigir, notificar (ANPD e afetados quando
houver risco relevante; prazo atual 3 dias úteis, VERIFY Res.
CD/ANPD 15/2024), aprender (teste de regressão + ADR). Log
datado em `docs/security/incidents.md` (sem dados pessoais).

## Registro de simulados

- 2026-10-03: kill switch em instância isolada local. Start e
  ping retornaram `503 maint` em < 30 s; leituras e dados
  estáticos seguiram funcionando; rollback apagando a chave.
  Próximo simulado: no VPS após T04/T05.