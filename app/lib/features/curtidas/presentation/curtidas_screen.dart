import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class CurtidasScreen extends StatelessWidget {
  const CurtidasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Curtidas',
      subtitle: 'Quem curtiu você e suas conexões.',
      showBack: false,
    );
  }
}
