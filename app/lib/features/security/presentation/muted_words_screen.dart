import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../application/security_providers.dart';

class MutedWordsScreen extends ConsumerWidget {
  const MutedWordsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final word = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silenciar palavra'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Palavra ou expressao'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.length < 2) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Silenciar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (word == null) return;

    try {
      await ref.read(securityRepositoryProvider).addMutedWord(word);
      ref.invalidate(mutedWordsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel silenciar a palavra.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mutedWordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Palavras silenciadas'),
        actions: [
          IconButton(
            tooltip: 'Adicionar',
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar.')),
        data: (words) {
          if (words.isEmpty) {
            return const Center(child: Text('Nenhuma palavra silenciada.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: words.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final word = words[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.text_fields_outlined),
                title: Text(word),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(securityRepositoryProvider)
                        .removeMutedWord(word);
                    ref.invalidate(mutedWordsProvider);
                  },
                  child: const Text('Remover'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
