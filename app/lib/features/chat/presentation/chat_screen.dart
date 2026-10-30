import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Chat',
      subtitle:
          'Conversa com $id. Coach e avisos de seguranca entram no B4/B5.',
    );
  }
}
