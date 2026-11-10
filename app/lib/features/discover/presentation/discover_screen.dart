import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../groups/presentation/groups_directory.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/data/ufv_courses.dart';
import '../../profile/presentation/incomplete_profile_banner.dart';
import '../../studies/presentation/studies_home.dart';
import '../application/discover_controller.dart';
import '../data/discover_models.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _section = 'people';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(discoverControllerProvider.notifier).load(reset: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Descobrir',
                          style: theme.textTheme.displayMedium,
                        ),
                      ),
                      const NotificationBell(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'people',
                        label: Text('Pessoas'),
                        icon: Icon(Icons.people_outline),
                      ),
                      ButtonSegment(
                        value: 'groups',
                        label: Text('Grupos'),
                        icon: Icon(Icons.groups_outlined),
                      ),
                      ButtonSegment(
                        value: 'studies',
                        label: Text('Estudos'),
                        icon: Icon(Icons.menu_book_outlined),
                      ),
                    ],
                    selected: {_section},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) {
                      FocusScope.of(context).unfocus();
                      setState(() => _section = value.first);
                    },
                  ),
                  const IncompleteProfileBanner(),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: switch (_section) {
                  'groups' => 1,
                  'studies' => 2,
                  _ => 0,
                },
                children: const [
                  _PeopleTab(),
                  GroupsDirectory(),
                  StudiesHome(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleTab extends ConsumerStatefulWidget {
  const _PeopleTab();

  @override
  ConsumerState<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends ConsumerState<_PeopleTab> {
  final _search = TextEditingController();
  Timer? _debounce;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                isExpanded: true,
                initialValue: state.course,
                decoration: const InputDecoration(labelText: 'Curso'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Todos os cursos'),
                  ),
                  ...ufvCourses.map(
                    (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
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
          child: _PeopleList(state: state, theme: theme),
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
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({required this.state, required this.theme});

  final DiscoverState state;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty && state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty) {
      return Center(
        child: Text(
          state.error ?? 'Nenhum perfil encontrado.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.72,
      ),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        return _DiscoverCard(profile: state.items[index]);
      },
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
