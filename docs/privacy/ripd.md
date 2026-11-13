# RIPD do Pontual (relatório de impacto, versão enxuta)

Data: 2026-10-03. Atualização: 2026-11-12 (agregados de aprendizado cumulativos, sem elegibilidade por aparelho). Responsável pela elaboração: equipe do app. Revisão do responsável e de advogado: pendente. Revisar antes da fase 2 e a cada mudança no tratamento de dados.

## 1. Tratamento descrito

Passageiros de ônibus em São Mateus compartilham a posição do ônibus durante a viagem. O servidor junta passageiros do mesmo ônibus em um veículo, elege um líder (envia com frequência) e mostra veículos por linha no mapa. Passageiros também podem enviar sinalizações públicas de curta duração (espera, ônibus lotado/quebrado, acesso bloqueado): para espera e acesso bloqueado, o app lê a localização uma vez e envia só uma célula de ~150 m; a posição exata não sai do aparelho. Sem texto livre, cadastro, histórico ou posição gravada em disco/banco. O subsistema de aprendizagem (0.3.x) deriva agregados de rotas, paradas e tempos a partir de viagens consentidas; não guarda coordenadas brutas nem ids de aparelho/viagem. A chegada pessoal na tela da linha faz uma leitura única da posição no aparelho, sem envio nem armazenamento; só a linha e o ponto vão ao servidor. Os agregados usam acumuladores no PostgreSQL (células de grade da rota, centróides de paradas, histogramas de duração por faixa de 15 min e dia da semana), sem ids de aparelho/viagem nem coordenadas brutas. Toda viagem consentida contribui; não há contador de elegibilidade por aparelho.

## 2. Necessidade e proporcionalidade

Sem a posição durante a viagem o serviço não existe; sem o código aleatório do aparelho não há como aplicar limites nem provar consentimento. Coleta mínima (ARCHITECTURE.md 13.2). Base legal: consentimento por viagem para posição; nada coletado de quem só olha. Finalidades legítimas e específicas. Retenção curta e apagamento imediato a pedido.

## 3. Riscos

| Risco | Causa | Prob. | Impacto | Controle |
| ----- | ----- | ----- | ------- | -------- |
| Posição exata de um passageiro sozinho (KL2) | um só passageiro = veículo | Alta | Alto | aviso no consentimento; sem histórico; some ao descer |
| Veículo fantasma (falsificação) | GPS falso ou abuso | Média | Médio | isMocked, plausibilidade, strikes, bloqueio, kill switch |
| Exposição de posição em registros | log acidental | Baixa | Alto | Log sem coordenadas (testado AC17); auditoria de logs |
| Perda do servidor (reinício) | instância única | Média | Baixo | retoma sozinho; sem dado permanente perdido além do ao vivo |
| Comprometimento do VPS | operação própria | Média | Alto | hardening, menor privilégio, backup cifrado, sem posição em disco |
| Transferência internacional de IP | Cloudflare, OSM, Google | Alta | Baixo | divulgado na política; Brasil preferido para o VPS |
| Menores expostos | estudantes usam | Média | Médio | mínimo de dados, sem perfil, sem anúncios |
| Presença inferida por sinalização | "alguém esperando" em ~150 m | Baixa | Médio | sem coordenada exata; célula grosseira; contagem 1 vira "alguém"; público por ação do titular; TTL <= 2 h; sem histórico |
| Localização exata em log ou relatório | bug de instrumentação | Baixa | Alto | só a célula é enviada; serviço converte no aparelho; revisão de logs; sem persistência |
| Sinalização falsa ou brigada | tokens gratuitos, retaliação | Média | Médio | tipos fechados, limites, teto por linha, TTL curto, texto "relato", kill switch |
| Leitura local única da posição | bug de instrumentação ou engano do titular | Baixa | Baixo | toque explícito, uma leitura, sem transmissão, sem persistência, descartada em até 5 minutos |
| Agregado de aprendizagem de um único passageiro | uma única viagem consentida já pode moldar rota, parada e tempos | Média | Médio | consentimento e opt-out; corte das pontas; sem ids de aparelho ou viagem; agregados cumulativos; contagem de amostras exibida; revisão do responsável e de advogado antes do lançamento público |

## 4. Risco residual

KL2 é inevitável em rastreador colaborativo e está divulgado no consentimento. Demais riscos com controles aplicados ficam baixos. Sem posição individual em repouso, o pior vazamento possível contém registros pseudônimos de aparelhos e centróides agregados de paradas e células de rota; esses centróides não identificam um aparelho, mas podem refletir o trajeto de uma única viagem.

## 5. Medidas e cronograma

- Revisão jurídica dos textos, incluindo o consentimento v2, o modelo cumulativo sem elegibilidade por aparelho e os agregados de aprendizado: pendente, antes da fase 2.
- Verificação ECA Digital (Lei 15.211/2025): pendente (V06).
- Confirmação da região do VPS: pendente (D24 verificou São Paulo, Brasil).
- Revisão deste RIPD: a cada mudança de dados ou incidente.