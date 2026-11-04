import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/discover_models.dart';
import '../data/discover_repository.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>(
  (ref) => DiscoverRepository(Supabase.instance.client),
);

class DiscoverState {
  const DiscoverState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.course,
    this.search = '',
    this.error,
  });

  final List<DiscoverProfile> items;
  final bool loading;
  final bool hasMore;
  final String? course;
  final String search;
  final String? error;

  DiscoverState copyWith({
    List<DiscoverProfile>? items,
    bool? loading,
    bool? hasMore,
    String? course,
    bool clearCourse = false,
    String? search,
    String? error,
    bool clearError = false,
  }) {
    return DiscoverState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      hasMore: hasMore ?? this.hasMore,
      course: clearCourse ? null : (course ?? this.course),
      search: search ?? this.search,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DiscoverController extends Notifier<DiscoverState> {
  static const int _pageSize = 30;

  @override
  DiscoverState build() => const DiscoverState();

  Future<void> load({bool reset = false}) async {
    if (state.loading) return;
    final offset = reset ? 0 : state.items.length;
    state = state.copyWith(
      loading: true,
      clearError: true,
      items: reset ? const [] : state.items,
    );
    try {
      final result = await ref
          .read(discoverRepositoryProvider)
          .fetch(
            limit: _pageSize,
            offset: offset,
            course: state.course,
            search: state.search,
          );
      state = state.copyWith(
        loading: false,
        items: reset ? result : [...state.items, ...result],
        hasMore: result.length == _pageSize,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Nao foi possivel carregar os perfis.',
      );
    }
  }

  Future<void> setCourse(String? course) async {
    state = state.copyWith(course: course, clearCourse: course == null);
    await load(reset: true);
  }

  Future<void> applySearch(String search) async {
    state = state.copyWith(search: search);
    await load(reset: true);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loading) return;
    await load();
  }
}

final discoverControllerProvider =
    NotifierProvider<DiscoverController, DiscoverState>(DiscoverController.new);
