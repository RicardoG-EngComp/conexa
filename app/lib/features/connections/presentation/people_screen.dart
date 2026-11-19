import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/media_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../connections/application/connection_providers.dart';
import '../../connections/data/connection_models.dart';
import '../../discover/application/discover_controller.dart';
import '../../discover/data/discover_models.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(discoverControllerProvider.notifier).load(reset: true),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _connect(String userId) async {
    try {
      await ref.read(connectionRepositoryProvider).sendRequest(userId);
    } catch (_) {
      if (mounted) _snack('Não foi possível enviar a solicitação.');
    }
  }

  Future<void> _respond(String userId, bool accept) async {
    try {
      await ref.read(connectionRepositoryProvider).respond(userId, accept);
    } catch (_) {
      if (mounted) _snack('Não foi possível responder agora.');
    }
  }

  Future<void> _cancel(String userId) async {
    try {
      await ref.read(connectionRepositoryProvider).cancelRequest(userId);
    } catch (_) {
      if (mounted) _snack('Não foi possível cancelar.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connections = ref.watch(connectionsProvider);
    final discover = ref.watch(discoverControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pessoas')),
      body: SafeArea(
        child: connections.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Erro ao carregar pessoas.')),
          data: (data) {
            final connectedIds = {
              ...data.incoming.map((item) => item.userId),
              ...data.outgoing.map((item) => item.userId),
              ...data.accepted.map((item) => item.userId),
            };
            final suggestions = discover.items
                .where((item) => !connectedIds.contains(item.id))
                .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                TextField(
                  controller: _search,
                  onChanged: (value) {
                    ref
                        .read(discoverControllerProvider.notifier)
                        .applySearch(value);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Buscar pessoas por nome ou curso',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                if (data.incoming.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(
                    title: 'Solicitações recebidas',
                    count: data.incoming.length,
                  ),
                  ...data.incoming.map(
                    (item) => _PersonRow(
                      entry: item,
                      actions: [
                        TextButton(
                          onPressed: () => _respond(item.userId, false),
                          child: const Text('Recusar'),
                        ),
                        FilledButton(
                          onPressed: () => _respond(item.userId, true),
                          child: const Text('Aceitar'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (data.outgoing.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(
                    title: 'Solicitações enviadas',
                    count: data.outgoing.length,
                  ),
                  ...data.outgoing.map(
                    (item) => _PersonRow(
                      entry: item,
                      actions: [
                        TextButton(
                          onPressed: () => _cancel(item.userId),
                          child: const Text('Cancelar'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (data.accepted.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(
                    title: 'Suas conexões',
                    count: data.accepted.length,
                  ),
                  ...data.accepted.map(
                    (item) => _PersonRow(
                      entry: item,
                      actions: [
                        TextButton(
                          onPressed: () =>
                              context.push('/profile/${item.userId}'),
                          child: const Text('Perfil'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _SectionTitle(
                  title: 'Sugestões para conectar',
                  count: suggestions.length,
                ),
                if (discover.loading && discover.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (suggestions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Text(
                      'Nenhuma sugestão no momento.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  )
                else
                  ...suggestions.map(
                    (item) => _SuggestionRow(
                      profile: item,
                      onConnect: () => _connect(item.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.entry, required this.actions});

  final ConnectionEntry entry;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _Avatar(name: entry.displayName, path: entry.avatarPath),
      title: Text(entry.displayName),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
      onTap: () => context.push('/profile/${entry.userId}'),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.profile, required this.onConnect});

  final DiscoverProfile profile;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _Avatar(name: profile.displayName, path: profile.avatarPath),
      title: Text(profile.displayName),
      subtitle: Text(
        [profile.course, profile.campus].where((e) => e.isNotEmpty).join(' · '),
      ),
      trailing: FilledButton(
        onPressed: onConnect,
        child: const Text('Conectar'),
      ),
      onTap: () => context.push('/profile/${profile.id}'),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.path});

  final String name;
  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      final initials = parts.isEmpty
          ? '?'
          : parts.length == 1
          ? parts.first.substring(0, 1).toUpperCase()
          : (parts.first.substring(0, 1) + parts.last.substring(0, 1))
                .toUpperCase();
      return CircleAvatar(
        backgroundColor: AppColors.teal,
        child: Text(
          initials,
          style: TextStyle(color: AppColors.onPrimary, fontSize: 12),
        ),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: MediaImage(path: path!, width: 40, height: 40),
      ),
    );
  }
}
