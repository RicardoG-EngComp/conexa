import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Descobrir',
      subtitle: 'Aqui aparece o feed de perfis com prompts.',
      showBack: false,
    );
  }
}
