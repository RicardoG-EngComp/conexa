import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/consent_gate.dart';

Future<void> showGuidelinesConsentDialog(BuildContext context) async {
  ConsentGate.invalidate();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Diretrizes da Comunidade'),
      content: const Text(
        'Para interagir na comunidade, voce precisa aceitar as '
        'Diretrizes da Comunidade.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Aceitar agora'),
        ),
      ],
    ),
  );
  if (context.mounted) context.go('/consent');
}
