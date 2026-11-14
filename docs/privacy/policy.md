# Política de Privacidade do Pontual (minuta)

Status: MINUTA para revisão do responsável e de advogado. Não publicar antes da revisão. Versão 2026-10-27 (minuta), texto do consentimento v2.

Itens [DEFINIR] dependem de decisão do responsável (identidade/contato, domínio, região do VPS). Ver DECISIONS.md INFRA-05, INFRA-23, D24.

## 1. Quem somos

Pontual: app independente e não oficial de acompanhamento de ônibus em São Mateus, ES. Não é da Viação São Gabriel nem da Prefeitura de São Mateus.

Controlador: [DEFINIR nome e contato]. Canal do titular: [DEFINIR e-mail]. Encarregado (DPO): [DEFINIR se houver].

## 2. O que coletamos e o que não coletamos

Coletamos somente:

- Código aleatório do aparelho (sem nome/e-mail/telefone), com datas de criação, último uso e expiração.
- Versão do consentimento aceito e quando.
- Durante a viagem: posição, velocidade, direção, precisão e bateria. Só na memória do servidor; some ao fim da viagem (máx. 10 min após último envio).
- Dados agregados da viagem (rotas, paradas, tempos) podem ser mantidos para melhorar previsões, sem identificação de aparelho ou viagem.
- Ônibus na tela: posição estimada do veículo (vários passageiros no mesmo ônibus viram um só ponto).
- Segurança: limites de uso por aparelho e por rede (só na memória, por minutos, sem registro permanente).
- Sinalizações: tipo, linha, área ~150 m, horário do servidor e contagem. Posição exata não enviada nem guardada. Públicas, só na memória, somem em até 2 h.

Opt-out de agregados: em "Privacidade e dados". Vale para próximas viagens; não pode ser desfeito no app; agregados já gerados não ligam ao aparelho e não são recalculados.

Nunca coletamos: nome, e-mail, telefone, contatos, fotos, microfone, histórico de viagens, IMEI ou identificadores de publicidade. Quem só olha o mapa/horários, sem compartilhar viagem nem sinalizar, não cria registro. A primeira sinalização cria o mesmo código anônimo usado para limitar abuso; a sinalização não é guardada junto desse código.

Leitura local opcional: na tela da linha, ao abrir em uma linha piloto, o app faz uma leitura automática em primeiro plano da posição do aparelho, só no aparelho, para achar o ponto mais próximo da linha e estimar a chegada; depois, enquanto a tela estiver aberta e o app em uso, com economia de dados desligada, atualiza no máximo uma vez por minuto. A posição exata não é enviada nem guardada; a previsão pede só a linha e o ponto. Fica na memória do app por até 5 min, pode ser recusada; o app funciona sem ela. O pedido do navegador/sistema é o único aviso de permissão na primeira vez. Durante uma viagem compartilhada ativa, o app reutiliza a última posição já mantida na memória, sem nova leitura, envio ou armazenamento.

## 3. Finalidades

- Mostrar onde está o ônibus da sua linha.
- Escolher qual celular envia com mais frequência (economia de bateria de todos).
- Provar consentimento e proteger o serviço contra abuso.
- Melhorar previsões com dados agregados de viagens, sem identificação de aparelho ou viagem.
- Mostrar sinalizações públicas de passageiros por alguns minutos.

## 4. Base legal (LGPD)

- Compartilhar posição: consentimento (art. 7, I), dado a cada viagem no botão "Estou no ônibus". Revogável quando quiser nesta tela ou apagando dados.
- Só olhar o mapa: nenhum dado seu coletado pelo app; registros de rede dos provedores seguem legítimo interesse (art. 7, IX).
- Sinalizações: você escolhe enviar. Para espera ou acesso bloqueado, o app lê sua localização uma vez e envia só área ~150 m; posição exata não sai do aparelho. Base legal e texto final pendentes de revisão do responsável e do advogado. A sinalização é pública e pode ser vista por outras pessoas.
- Leitura local opcional: consentimento dado pela permissão de localização do navegador/sistema, pedida na primeira abertura da tela da linha piloto. Leitura em primeiro plano, fica no aparelho; nada enviado nem guardado. Base legal e texto final pendentes de revisão do responsável e do advogado.

## 5. Retenção

- Posição: some da memória ao fim da viagem.
- Código do aparelho e consentimento: até você apagar ou 30 dias sem uso.
- Sinalizações: máx. 2 h, só na memória, máx. uma célula ~150 m; somem ao reiniciar o serviço ou ao usar "Apagar meus dados".
- Cópias de segurança cifradas: 30 dias.
- Leitura local opcional: posição lida fica no aparelho máx. 5 min, descartada ao sair ou atualizar.

## 6. Quem recebe os dados

Ninguém recebe seus dados para marketing ou venda. Operam conosco: provedor do servidor ([DEFINIR]), Cloudflare (rede e segurança) e servidores de mapa OpenStreetMap (veem endereço de rede ao carregar o mapa). Ver docs/privacy/inventory.md.

## 7. Transferência internacional

Servidor fica [DEFINIR região; preferência: Brasil]. Provedores globais (Cloudflare, Google, OpenStreetMap) podem tratar endereço de rede fora do Brasil.

## 8. Seus direitos (art. 18)

Confirmação, acesso, correção, anonimização, bloqueio, eliminação, portabilidade, informação e revogação do consentimento. Como não guardamos histórico, o principal direito se exerce no app: "Apagar meus dados" apaga tudo na hora. Pedidos pelo canal do titular acima; prazo legal de resposta.

## 9. Segurança

Conexões cifradas, sem senhas, código do aparelho revogável, posição nunca gravada em disco ou banco, sem kits de análise ou anúncios, registros sem coordenadas.

## 10. Crianças e adolescentes

App não dirigido a crianças. Estudantes usam com o mínimo de dados acima, sem perfil, sem anúncios e sem truques de engajamento.

## 11. Mudanças nesta política

Mudanças relevantes geram nova versão do texto de consentimento e novo pedido de aceite antes da próxima viagem.

Data desta minuta: 03/10/2026.