// Bundled privacy texts (pt-BR, short drafts). The full policy and
// terms drafts live in docs/privacy/ (T42); these summaries ship in
// the app so they work offline. Lawyer review is pending.
library;

/// Short privacy policy shown in-app.
const String bundledPolicy = '''
Pontual: política de privacidade (resumo)

Quem somos: app independente e não oficial de acompanhamento de ônibus em São Mateus.

O que coletamos:
- Código anônimo do celular, sem nome, e-mail ou telefone.
- Versão do consentimento aceita e quando.
- Durante a viagem: posição, velocidade, direção, precisão e bateria do celular. Fica só na memória do servidor e some quando a viagem termina.
- Dados anonimizados da viagem (rotas, paradas e tempos) podem ser mantidos para melhorar previsões. Você pode desativar em Ajustes.
- Avisos: tipo, linha, área aproximada de ~150 m, horário do servidor e contagem de celulares. A posição exata não é enviada nem guardada. São públicos, ficam na memória e somem em até 2 horas.
- Leitura local opcional em "Ver quando chega no meu ponto": a posição é lida uma vez, só no celular, e descartada em até 5 minutos. Nada é enviado.
- Para evitar abuso: limites por celular e por rede, só na memória, sem registro permanente.
- Quem só olha o mapa ou os horários não cria registro.

O que nunca coletamos: nome, e-mail, telefone, contatos, fotos, microfone, histórico de viagens, IMEI ou identificadores de publicidade.

Por quanto tempo guardamos: a posição some ao fim da viagem; avisos somem em até 2 horas; o código do celular e o consentimento ficam até você apagar ou 30 dias sem uso; cópias de segurança cifradas ficam 30 dias.

Seus direitos: você pode revogar o consentimento e apagar seus dados a qualquer momento nesta tela. Tratamos os dados conforme a LGPD (Brasil).

Segurança: conexões cifradas com TLS, sem senhas, código do celular revogável, sem analytics e sem anúncios.

Versão do resumo: 1.0. Revisão jurídica pendente.
''';

/// Short terms of use shown in-app.
const String bundledTerms = '''
Pontual: termos de uso (resumo)

- App independente e não oficial. Não é da Viação São Gabriel nem da Prefeitura de São Mateus.
- Horários não oficiais e posições aproximadas: sem garantia de exatidão ou disponibilidade.
- Seja honesto: compartilhe só quando estiver no ônibus, sem localizações falsas e sem automação.
- Avisos são relatos públicos de passageiros, não são informação oficial. Para espera ou acesso bloqueado, usamos uma área de ~150 m, não a posição exata.
- Podemos encerrar viagens, remover avisos e bloquear celulares em caso de abuso.
- Lei aplicável: Brasil.

Versão do resumo: 1.0. Revisão jurídica pendente.
''';
