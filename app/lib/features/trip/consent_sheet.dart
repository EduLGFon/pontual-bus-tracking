// S06 share-trip sheet: prominent disclosure plus consent. Shown before
// the first trip and whenever consent_version changes. No pre-ticked
// boxes; dismissible without side effects. See PLAN.md S06.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Result of the consent sheet.
enum ConsentChoice {
  /// User accepted and wants to continue.
  accepted,

  /// User declined or dismissed.
  declined,
}

/// Bottom sheet with the prominent location disclosure in pt-BR.
class ConsentSheet extends StatelessWidget {
  /// Creates the consent sheet.
  const ConsentSheet({super.key});

  /// Shows the sheet and returns the user choice.
  static Future<ConsentChoice> show(BuildContext context) async {
    final bool? accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Root navigator so the sheet slides above the shell dock pill. D-U26.
      useRootNavigator: true,
      builder: (BuildContext context) => const ConsentSheet(),
    );
    return accepted == true ? ConsentChoice.accepted : ConsentChoice.declined;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Compartilhar sua localização',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Para mostrar onde o ônibus está, este app coleta a '
              'localização do seu celular enquanto a viagem estiver ativa - '
              'inclusive com a tela bloqueada ou o app em segundo plano.\n\n'
              '• Usada só para posicionar o ônibus no mapa.\n'
              '• Não é ligada ao seu nome, e-mail ou telefone.\n'
              '• É apagada quando a viagem termina.\n'
              '• Outros usuários veem a posição do ônibus, não quem está nele. '
              'Se só você compartilhar, a posição do ônibus é a sua.\n'
              '• Você pode encerrar quando quiser.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            TextButton(
              onPressed: () => context.go('/privacy'),
              child: const Text('Política de Privacidade'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aceitar e continuar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Agora não'),
            ),
          ],
        ),
      ),
    );
  }
}
