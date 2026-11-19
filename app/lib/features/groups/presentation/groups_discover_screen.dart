import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import 'groups_directory.dart';

class GroupsDiscoverScreen extends StatelessWidget {
  const GroupsDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Descobrir grupos')),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: GroupsDirectory(),
        ),
      ),
    );
  }
}
