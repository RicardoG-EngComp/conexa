import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/data/ufv_courses.dart';
import '../application/discover_controller.dart';
import '../data/discover_models.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(discoverControllerProvider.notifier).load(reset: true),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(discoverControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Descobrir', style: theme.textTheme.displayMedium),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nome ou curso...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 400),
                        () => ref
                            .read(discoverControllerProvider.notifier)
                            .applySearch(value),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: state.course,
                    decoration: const InputDecoration(labelText: 'Curso'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos os cursos'),
                      ),
                      ...ufvCourses.map(
                        (c) =>
                            DropdownMenuItem<String>(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (value) => ref
                        .read(discoverControllerProvider.notifier)
                        .setCourse(value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.items.isEmpty && state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.items.isEmpty
                  ? Center(
                      child: Text(
                        state.error ?? 'Nenhum perfil encontrado.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.md,
                            crossAxisSpacing: AppSpacing.md,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: state.items.length,
                      itemBuilder: (context, index) {
                        return _DiscoverCard(profile: state.items[index]);
                      },
                    ),
            ),
            if (state.hasMore)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: OutlinedButton(
                  onPressed: state.loading
                      ? null
                      : () => ref
                            .read(discoverControllerProvider.notifier)
                            .loadMore(),
                  child: state.loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Carregar mais'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverCard extends ConsumerWidget {
  const _DiscoverCard({required this.profile});

  final DiscoverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/profile/${profile.id}'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _DiscoverAvatar(path: profile.avatarPath)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    profile.course,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    profile.campus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverAvatar extends ConsumerWidget {
  const _DiscoverAvatar({this.path});

  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fallback = ColoredBox(
      color: AppColors.border,
      child: Center(child: Icon(Icons.person, size: 48)),
    );
    if (path == null || path!.isEmpty) return fallback;
    final url = ref.watch(signedUrlProvider(path!));
    final value = url.asData?.value;
    if (value == null) return fallback;
    return Image.network(value, fit: BoxFit.cover, width: double.infinity);
  }
}
