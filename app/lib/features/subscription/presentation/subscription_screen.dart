import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Assinatura',
      subtitle: 'R\$ 10/mes ou R\$ 5/mes com indicacao. Cobranca via Pix.',
    );
  }
}
