# Inventário de dados do Pontual

Fonte: ARCHITECTURE.md 13.2. Atualizar a cada mudança no tratamento. Última revisão: 2026-11-14.

| Dado | Finalidade | Onde | Retenção | Pessoal? |
| ---- | ---------- | ---- | -------- | -------- |
| Código do aparelho + hash do token, criação/último uso/expiração, flag de opt-out de aprendizado | limites, titularidade, prova de consentimento, controle de contribuição | PostgreSQL `devices` | até apagar ou 30 dias inativo | Sim (pseudônimo) |
| Versão do consentimento + data | prova de consentimento (art. 8, par. 2) | PostgreSQL `consents` | com o registro do aparelho | Sim |
| Bloqueio (código, motivo) | controle de abuso | PostgreSQL `blocked_devices` | com o registro do aparelho | Sim (pseudônimo) |
| Última posição: lat, lng, velocidade, direção, precisão | posicionar o ônibus | memória do servidor | até o fim da viagem | Sim (localização) |
| Bateria (faixas de 5%) + carregando | eleger líder | memória do servidor | até o fim da viagem | Sim (estado do aparelho) |
| Posição do veículo (junção) | mostrar o ônibus | memória do servidor | some após 120 s sem sinal | Pode revelar passageiro sozinho (KL2) |
| Ritmo do veículo (velocidade suavizada) | ETA e previsão | memória do servidor, no veículo | com o veículo; zera a cada ônibus novo | Não identifica motorista; sem histórico |
| Passagens recentes (só instantes por linha) | frequência, histórico, atrasos | memória do servidor | anel de 32, 4 h | Sem posição, sem identidade |
| Agregados de aprendizado (rotas, paradas, células de grade, tempos de trecho e de parada, contagens) | ETA, previsão de chegada e geometria | PostgreSQL (`learned_*`, `learning_*`) | enquanto a parada ou linha existir; parada sem passagem por 90 dias é desativada e apagada após 180 dias; rota aposentada após 30 dias | Não identificado; risco residual de reidentificação, pois uma única viagem consentida pode moldar o agregado |
| Sinalização (tipo, linha, célula ~150 m, horários do servidor, contagem) | aviso público de curta duração | memória do servidor | TTL 10-30 min; máx 2 h; some ao reiniciar | Presença aproximada; público, sem identificador durável |
| Limites por IP/aparelho | controle de abuso | memória do servidor | minutos; sem registro | Sim (IP), efêmero |
| Registros de infra (IP, agente) | segurança/operação | Cloudflare, OSM, provedor VPS; próprios desligados ou sem IP | por provedor (curto) | Sim (IP), no provedor |
| Backups cifrados das tabelas | recuperação | fora do servidor | 30 dias | Sim (pseudônimo), cifrado |
| Preferências locais (tema, consentimento, token) | uso do app | aparelho | até desinstalar ou apagar dados | Token é credencial, sem PII |
| Recentes, atalhos casa/trabalho/escola, paradas, alertas, contador | atalhos e avisos | aparelho (`shared_preferences`) | até limpar ou apagar dados | Só no aparelho; nada vai ao servidor |
| Localização do aparelho para achar o ponto mais próximo (leituras automáticas em primeiro plano enquanto a tela da linha está aberta; durante viagem ativa reutiliza a última posição já na memória) | estimar a chegada até o ponto da linha | memória do app | fica na memória do app durante a sessão; a última leitura vale por 5 min; descartada ao sair | Sim (localização), não sai do aparelho |

Nunca coletado: nome, e-mail, telefone, contatos, IMEI, identificadores de publicidade, apps instalados, fotos, microfone, histórico de viagens (não há histórico nem contador por aparelho). Quem só olha, sem compartilhar viagem e sem sinalizar, não cria registro. A primeira sinalização cria o mesmo código anônimo de aparelho usado contra abuso; a sinalização não é guardada junto desse código.