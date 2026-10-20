// Bundled privacy texts (pt-BR, short drafts). The full policy and
// terms drafts live in docs/privacy/ (T42); these summaries ship in
// the app so they work offline. Lawyer review is pending.
library;

/// Short privacy policy shown in-app.
const String bundledPolicy = '''
Pontual: política de privacidade (resumo)

Quem somos: app independente e não oficial de acompanhamento de
ônibus em São Mateus. O canal de contato do responsável está nas
configurações quando definido.

O que coletamos:
- Um código aleatório do aparelho (sem nome, e-mail ou telefone).
- A versão do consentimento que você aceitou e quando.
- Durante a viagem: posição, velocidade e bateria do celular. Isso
  fica só na memória do servidor e some quando a viagem termina.
- Sinalizações: tipo, linha e uma área aproximada de ~150 m, públicas
  por até 2 horas. A posição exata não é enviada nem guardada.
- Quem só olha o mapa ou os horários, sem compartilhar e sem
  sinalizar, não cria registro nenhum.

O que nunca coletamos: nome, e-mail, telefone, contatos, fotos,
microfone, histórico de viagens ou identificadores do aparelho.

Seus direitos: você pode revogar o consentimento e apagar seus
dados a qualquer momento nesta tela ("Apagar meus dados").

Texto completo: docs/privacy/policy.md. Revisão por advogado pendente.
''';

/// Short terms of use shown in-app.
const String bundledTerms = '''
Pontual: termos de uso (resumo)

- App independente e não oficial. Não é da Viação São Gabriel nem
  da Prefeitura de São Mateus.
- Horários não oficiais e posições aproximadas: sem garantia de
  exatidão ou disponibilidade.
- Use honesto: compartilhe só quando estiver no ônibus, sem
  localizações falsas e sem automação.
- Sinalizações são relatos públicos de passageiros, não informação
  oficial. Para espera ou acesso bloqueado, usamos uma área de
  ~150 m, não a posição exata.
- Podemos encerrar viagens, remover sinalizações e bloquear
  aparelhos em caso de abuso.
- Lei aplicável: Brasil.

Texto completo: docs/privacy/terms.md. Revisão por advogado pendente.
''';
