import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Coach',
      subtitle:
          'Dicas de foto, sugestoes de conversa e analise de perfil. '
          'Exclusivo para assinantes.',
      showBack: false,
    );
  }
}
