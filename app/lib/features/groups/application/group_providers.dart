import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/group_models.dart';
import '../data/group_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepository(Supabase.instance.client),
);

final myGroupsProvider = FutureProvider.autoDispose<List<UserGroup>>(
  (ref) => ref.read(groupRepositoryProvider).fetchMyGroups(),
);

final groupDetailProvider = FutureProvider.autoDispose
    .family<GroupDetail?, String>(
      (ref, id) => ref.read(groupRepositoryProvider).fetchGroupDetail(id),
    );

final groupRolesProvider = FutureProvider.autoDispose
    .family<List<GroupRole>, String>(
      (ref, id) => ref.read(groupRepositoryProvider).fetchRoles(id),
    );

final groupMembersProvider = FutureProvider.autoDispose
    .family<List<GroupMember>, String>(
      (ref, id) => ref.read(groupRepositoryProvider).fetchMembers(id),
    );

final groupInvitesProvider = FutureProvider.autoDispose
    .family<List<GroupInvite>, String>(
      (ref, id) => ref.read(groupRepositoryProvider).fetchInvites(id),
    );

final groupFollowersProvider = FutureProvider.autoDispose
    .family<List<GroupFollower>, String>(
      (ref, id) => ref.read(groupRepositoryProvider).fetchFollowers(id),
    );

final myGroupInvitesProvider =
    FutureProvider.autoDispose<List<GroupInvitation>>(
      (ref) => ref.read(groupRepositoryProvider).fetchMyInvites(),
    );

final groupDirectoryProvider = FutureProvider.autoDispose
    .family<List<GroupSummary>, String>(
      (ref, search) =>
          ref.read(groupRepositoryProvider).fetchDirectory(search: search),
    );

final pendingGroupsProvider = FutureProvider.autoDispose<List<GroupSummary>>(
  (ref) => ref.read(groupRepositoryProvider).fetchPendingGroups(),
);

final groupModeratorFlagProvider = FutureProvider.autoDispose
    .family<bool, String>(
      (ref, groupId) => ref
          .read(groupRepositoryProvider)
          .hasPermission(groupId, 'moderate_content'),
    );

final groupEventsProvider = FutureProvider.autoDispose
    .family<List<GroupEvent>, String>(
      (ref, groupId) => ref.read(groupRepositoryProvider).fetchEvents(groupId),
    );

final groupAnalyticsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, groupId) =>
          ref.read(groupRepositoryProvider).fetchAnalytics(groupId),
    );

final groupEventRsvpsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
      (ref, groupId) =>
          ref.read(groupRepositoryProvider).fetchEventRsvps(groupId),
    );
