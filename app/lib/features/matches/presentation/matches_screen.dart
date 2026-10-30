import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Curtidas',
      subtitle: 'Quem curtiu voce e seus matches.',
      showBack: false,
    );
  }
}
