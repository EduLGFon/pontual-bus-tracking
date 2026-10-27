# Política de Privacidade do Pontual (minuta)

Status: MINUTA para revisão do responsável e de advogado. Não publicar
antes da revisão. Versão 2026-10-27 (minuta), texto do consentimento v2.

Itens marcados com [DEFINIR] dependem de decisão do responsável
(identidade e contato, domínio, região do VPS). Ver DECISIONS.md
INFRA-05, INFRA-23 e D24.

## 1. Quem somos

O Pontual é um aplicativo independente e não oficial de
acompanhamento de ônibus em São Mateus, ES. Não é da Viação São
Gabriel nem da Prefeitura de São Mateus.

Controlador: [DEFINIR nome e contato]. Canal do titular:
[DEFINIR e-mail]. Encarregado (DPO): [DEFINIR se houver].

## 2. O que coletamos e o que não coletamos

Coletamos somente:

- Código aleatório do aparelho (sem nome, e-mail ou telefone),
  com datas de criação, último uso e expiração.
- Versão do consentimento aceito e quando.
- Durante a viagem: posição, velocidade, direção, precisão e
  bateria do celular. Fica só na memória do servidor e some
  quando a viagem termina (no máximo 10 minutos após o último
  envio).
- Dados anonimizados da viagem, como rotas, paradas e tempos,
  podem ser mantidos para melhorar previsões, sem identificação.
- Ônibus na tela: posição estimada do veículo (vários passageiros
  no mesmo ônibus viram um só ponto no mapa).
- Para segurança: limites de uso por aparelho e por rede (só na
  memória, por minutos, sem registro permanente).
- Sinalizações que você envia: tipo, linha, uma área aproximada de
  cerca de 150 m, horário do servidor e contagem de aparelhos. A
  posição exata não é enviada nem guardada. São públicas, ficam só
  na memória do servidor e somem em até 2 horas.

Nunca coletamos: nome, e-mail, telefone, contatos, fotos,
microfone, histórico de viagens, IMEI ou identificadores de
publicidade. Quem só olha o mapa ou os horários, sem compartilhar
viagem e sem sinalizar, não cria registro nenhum. A primeira
sinalização cria o mesmo código anônimo de aparelho usado para
limitar abuso; a sinalização não é guardada junto desse código.

## 3. Para que usamos (finalidades)

- Mostrar onde está o ônibus da sua linha.
- Escolher qual celular envia com mais frequência (economia de
  bateria de todos).
- Provar o seu consentimento e proteger o serviço contra abuso.
- Melhorar previsões com dados anonimizados agregados de viagens.
- Mostrar sinalizações públicas de passageiros por alguns minutos.

## 4. Base legal (LGPD)

- Compartilhar a posição: consentimento (art. 7, I), dado a cada
  viagem no botão "Estou no ônibus". Você pode revogar quando
  quiser nesta tela ou apagando seus dados.
- Só olhar o mapa: nenhum dado seu é coletado pelo app;
  registros de rede dos provedores seguem o legítimo interesse
  (art. 7, IX).
- Sinalizações: você escolhe enviar. Para espera ou acesso
  bloqueado, o app lê sua localização uma vez e envia só uma área
  aproximada de ~150 m; a posição exata não sai do aparelho. A
  base legal e o texto final serão confirmados pelo responsável e
  pelo advogado. A sinalização é pública e pode ser vista por
  outras pessoas.

## 5. Por quanto tempo guardamos

- Posição: some da memória ao fim da viagem.
- Código do aparelho e consentimento: até você apagar ou 30 dias
  sem uso.
- Sinalizações: no máximo 2 horas, só na memória, guardando no
  máximo uma célula de ~150 m; somem ao reiniciar o serviço ou ao
  usar "Apagar meus dados".
- Cópias de segurança cifradas: 30 dias.

## 6. Quem recebe os dados

Ninguém recebe seus dados para marketing ou venda. Operam
conosco: o provedor do servidor ([DEFINIR]), a Cloudflare
(rede e segurança) e os servidores de mapa OpenStreetMap (veem
o endereço de rede ao carregar o mapa). Ver docs/privacy/inventory.md.

## 7. Transferência internacional

O servidor fica [DEFINIR região; preferência: Brasil]. Provedores
globais (Cloudflare, Google, OpenStreetMap) podem tratar o
endereço de rede fora do Brasil.

## 8. Seus direitos (art. 18)

Confirmação, acesso, correção, anonimização, bloqueio, eliminação,
portabilidade, informação e revogação do consentimento. Como não
guardamos histórico, o principal direito se exerce aqui no app:
"Apagar meus dados" apaga tudo na hora. Pedidos pelo canal do
titular acima; prazo legal de resposta.

## 9. Segurança

Conexões cifradas, sem senhas, código do aparelho revogável,
posição nunca gravada em disco ou banco, sem kits de análise ou
anúncios, registros sem coordenadas.

## 10. Crianças e adolescentes

O app não é dirigido a crianças. Estudantes usam com o mínimo de
dados acima, sem perfil, sem anúncios e sem truques de engajamento.

## 11. Mudanças nesta política

Mudanças relevantes geram nova versão do texto de consentimento
e novo pedido de aceite antes da próxima viagem.

Data desta minuta: 03/10/2026.