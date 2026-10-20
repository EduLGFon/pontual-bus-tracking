# Inventário de dados do Pontual

Fonte: PLAN.md 13.2. Manter atualizado a cada mudança no tratamento.
Última revisão: 2026-10-20 (D82).

| Dado | Finalidade | Onde | Retenção | Dado pessoal? |
| ---- | ---------- | ---- | -------- | ------------- |
| Código do aparelho + hash do token, criação/último uso/expiração | limites, titularidade, prova de consentimento | PostgreSQL `devices` | até apagar ou 30 dias inativo | Sim (pseudônimo) |
| Versão do consentimento + data | prova de consentimento (art. 8, par. 2) | PostgreSQL `consents` | com o registro do aparelho | Sim (ligado ao pseudônimo) |
| Bloqueio (código, motivo) | controle de abuso | PostgreSQL `blocked_devices` | com o registro do aparelho | Sim (pseudônimo) |
| Última posição: lat, lng, velocidade, direção, precisão | posicionar o ônibus | memória do servidor | até o fim da viagem | Sim (localização) |
| Bateria (faixas de 5%) + carregando | eleger líder | memória do servidor | até o fim da viagem | Sim (estado do aparelho) |
| Posição do veículo (junção) | mostrar o ônibus | memória do servidor | some após 120 s sem sinal | Pode revelar passageiro sozinho (KL2) |
| Ritmo do veículo (velocidade suavizada, um número) | ETA e previsão | memória do servidor, no veículo | com o veículo; zera a cada ônibus novo | Não identifica motorista; sem histórico |
| Passagens recentes (só instantes por linha) | frequência, histórico, atrasos | memória do servidor | anel de 32, 4 h | Sem posição, sem identidade |
| Sinalização (tipo, linha, ponto, horários do servidor, contagem de aparelhos) | aviso público de curta duração | memória do servidor | TTL de 10 a 30 min; máximo 2 h; some ao reiniciar | Pode revelar presença em um ponto; público, sem identificador durável |
| Limites por IP/aparelho | controle de abuso | memória do servidor | minutos; sem registro | Sim (IP), efêmero |
| Registros de infra (IP, agente) | segurança/operação | Cloudflare, OSM, provedor VPS; próprios desligados ou sem IP | por provedor (curto) | Sim (IP), no provedor |
| Backups cifrados das tabelas | recuperação | fora do servidor | 30 dias | Sim (pseudônimo), cifrado |
| Preferências locais (tema, consentimento, token) | uso do app | aparelho | até desinstalar ou apagar dados | Token é credencial, sem PII |
| Recentes, atalhos casa/trabalho/escola, paradas, alertas, contador | atalhos e avisos | aparelho (`shared_preferences`) | até limpar ou apagar dados | Só no aparelho; nada vai ao servidor |

Nunca coletado: nome, e-mail, telefone, contatos, IMEI,
identificadores de publicidade, apps instalados, fotos,
microfone, histórico de viagens. Quem só olha, sem compartilhar
viagem e sem sinalizar, não cria registro. A primeira sinalização
cria o mesmo código anônimo de aparelho usado contra abuso; a
sinalização em si não é guardada junto desse código.
