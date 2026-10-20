# RIPD do Pontual (relatório de impacto, versão enxuta)

Data: 2026-10-03. Atualização: 2026-10-20 (D83). Responsável pela elaboração: equipe do app.
Revisão do responsável e de advogado: pendente. Revisar antes da
fase 2 e a cada mudança no tratamento de dados.

## 1. Tratamento descrito

Passageiros de ônibus em São Mateus compartilham a posição do
ônibus durante a viagem. O servidor junta passageiros do mesmo
ônibus em um veículo, elege um líder (envia com frequência) e
mostra veículos por linha no mapa. Passageiros também podem
enviar sinalizações públicas de curta duração (espera, ônibus
lotado/quebrado, acesso bloqueado). Para espera e acesso
bloqueado, o app lê a localização uma vez e envia só uma célula de
~150 m; a posição exata não sai do aparelho. Sem texto livre, sem
cadastro, sem histórico, sem posição gravada em disco ou banco.

## 2. Necessidade e proporcionalidade

Sem a posição durante a viagem o serviço não existe; sem o código
aleatório do aparelho não há como aplicar limites nem provar
consentimento. Coleta mínima (PLAN.md 13.2). Base legal:
consentimento por viagem para posição; nada coletado de quem só
olha. Finalidades legítimas e específicas. Retenção curta e
apagamento imediato a pedido.

## 3. Riscos

| Risco | Causa | Probabilidade | Impacto | Controle |
| ----- | ----- | ------------- | ------- | -------- |
| Posição exata de um passageiro sozinho (KL2) | um só passageiro = veículo | Alta | Alto | aviso no consentimento; sem histórico; some ao descer |
| Veículo fantasma (falsificação) | GPS falso ou abuso | Média | Médio | isMocked, plausibilidade, strikes, bloqueio, kill switch |
| Exposição de posição em registros | log acidental | Baixa | Alto | Log sem coordenadas (testado AC17); auditoria de logs |
| Perda do servidor (reinício) | instância única | Média | Baixo | retoma sozinho; sem dado permanente perdido além do ao vivo |
| Comprometimento do VPS | operação própria | Média | Alto | hardening, menor privilégio, backup cifrado, sem posição em disco |
| Transferência internacional de IP | Cloudflare, OSM, Google | Alta | Baixo | divulgado na política; Brasil preferido para o VPS |
| Menores expostos | estudantes usam | Média | Médio | mínimo de dados, sem perfil, sem anúncios |
| Presença inferida por sinalização | "alguém esperando" em uma área de ~150 m | Baixa | Médio | sem coordenada exata; célula grosseira; contagem 1 vira "alguém"; público por ação do titular; TTL <= 2 h; sem histórico |
| Localização exata em log ou relatório | bug de instrumentação | Baixa | Alto | só a célula é enviada; serviço converte no aparelho; revisão de logs; sem persistência |
| Sinalização falsa ou brigada | tokens gratuitos, retaliação | Média | Médio | tipos fechados, limites, teto por linha, TTL curto, texto "relato", kill switch |

## 4. Risco residual

KL2 é inevitável em rastreador colaborativo e está divulgado no
consentimento. Demais riscos com controles aplicados ficam
baixos. Sem posição em repouso, o pior vazamento possível contém
no máximo registros pseudônimos de aparelhos.

## 5. Medidas e cronograma

- Revisão jurídica dos textos: antes da fase 2.
- Verificação ECA Digital (Lei 15.211/2025): pendente (V06).
- Confirmação da região do VPS: pendente (D24 verificou São
  Paulo, Brasil).
- Revisão deste RIPD: a cada mudança de dados ou incidente.
