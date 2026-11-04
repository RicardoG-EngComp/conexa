import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/block_providers.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios bloqueados')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar.')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('Nenhum usuario bloqueado.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final row = rows[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.teal,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text((row['display_name'] as String?) ?? 'UFV'),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(blockRepositoryProvider)
                        .unblock(row['id'] as String);
                    ref.invalidate(blockedUsersProvider);
                  },
                  child: const Text('Desbloquear'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
