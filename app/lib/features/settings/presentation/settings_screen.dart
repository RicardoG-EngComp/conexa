import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Configuracoes',
      subtitle: 'Privacidade, consentimentos, localizacao, seguranca e exclusao de conta.',
      showBack: false,
    );
  }
}
