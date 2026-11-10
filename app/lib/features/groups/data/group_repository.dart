import 'package:supabase_flutter/supabase_flutter.dart';

import 'group_models.dart';

class GroupRepository {
  GroupRepository(this._client);

  final SupabaseClient _client;

  static const List<String> allPermissions = [
    'manage_group',
    'manage_roles',
    'manage_members',
    'manage_invites',
    'post_as_group',
    'moderate_content',
  ];

  Future<List<UserGroup>> fetchMyGroups() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final memberRows = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', user.id)
        .eq('status', 'active');
    final groupIds = (memberRows as List)
        .map((r) => r['group_id'] as String)
        .toSet()
        .toList();
    if (groupIds.isEmpty) return [];

    final groupRows = await _client
        .from('groups')
        .select('id, name, is_official, visibility, public_approval')
        .inFilter('id', groupIds);
    final groups = <String, Map<String, dynamic>>{};
    for (final g in (groupRows as List)) {
      groups[g['id'] as String] = g as Map<String, dynamic>;
    }

    final mrRows = await _client
        .from('group_member_roles')
        .select('group_id, role_id')
        .eq('user_id', user.id)
        .inFilter('group_id', groupIds);
    final roleIdsByGroup = <String, List<String>>{};
    final roleIds = <String>[];
    for (final r in (mrRows as List)) {
      final gid = r['group_id'] as String;
      final rid = r['role_id'] as String;
      roleIdsByGroup.putIfAbsent(gid, () => []).add(rid);
      roleIds.add(rid);
    }

    final roleMap = <String, UserGroupRole>{};
    if (roleIds.isNotEmpty) {
      final roleRows = await _client
          .from('group_roles')
          .select('id, name, permissions')
          .inFilter('id', roleIds.toSet().toList());
      for (final r in (roleRows as List)) {
        roleMap[r['id'] as String] = UserGroupRole(
          id: r['id'] as String,
          name: r['name'] as String,
          permissions: ((r['permissions'] as List?) ?? const [])
              .map((e) => e as String)
              .toList(),
        );
      }
    }

    return groupIds.map((gid) {
      final g = groups[gid];
      if (g == null) return null;
      final roleObjs = (roleIdsByGroup[gid] ?? const [])
          .map((rid) => roleMap[rid])
          .whereType<UserGroupRole>()
          .toList();
      final isPublicVerified = g['visibility'] == 'public' &&
          g['public_approval'] == 'approved' &&
          g['is_official'] == true;
      return UserGroup(
        id: gid,
        name: g['name'] as String,
        isOfficial: g['is_official'] == true,
        isPublicVerified: isPublicVerified,
        roles: roleObjs,
      );
    }).whereType<UserGroup>().toList();
  }

  Future<GroupDetail?> fetchGroupDetail(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('groups')
        .select(
          'id, name, description, category, campus, course, visibility, '
          'public_approval, is_official, under_review, owner_id',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;

    final statsList =
        (await _client.rpc('group_stats', params: {'p_group_id': id}) as List)
            .cast<Map<String, dynamic>>();
    final stats = statsList.isEmpty ? const <String, dynamic>{} : statsList.first;
    final memberCount = stats['member_count'] as int? ?? 0;
    final followerCount = stats['follower_count'] as int? ?? 0;

    final memberRow = await _client
        .from('group_members')
        .select('status')
        .eq('group_id', id)
        .eq('user_id', user.id)
        .eq('status', 'active')
        .maybeSingle();
    final isMember = memberRow != null;

    final followRow = await _client
        .from('group_followers')
        .select('user_id')
        .eq('group_id', id)
        .eq('user_id', user.id)
        .maybeSingle();
    final isFollowing = followRow != null;

    return GroupDetail(
      id: row['id'] as String,
      name: row['name'] as String,
      category: (row['category'] as String?) ?? 'Outros',
      campus: (row['campus'] as String?) ?? 'Viçosa',
      visibility: (row['visibility'] as String?) ?? 'private',
      publicApproval: (row['public_approval'] as String?) ?? 'none',
      isOfficial: row['is_official'] == true,
      ownerId: row['owner_id'] as String,
      description: row['description'] as String?,
      course: row['course'] as String?,
      isMember: isMember,
      isFollowing: isFollowing,
      memberCount: memberCount,
      followerCount: followerCount,
      permissions: await _fetchMyPermissions(id, row['owner_id'] as String),
    );
  }

  Future<List<String>> _fetchMyPermissions(String groupId, String ownerId) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final perms = <String>{};
    if (ownerId == user.id) perms.addAll(allPermissions);

    final mrRows = await _client
        .from('group_member_roles')
        .select('role_id')
        .eq('group_id', groupId)
        .eq('user_id', user.id);
    final roleIds = (mrRows as List).map((r) => r['role_id'] as String).toList();
    if (roleIds.isNotEmpty) {
      final roleRows = await _client
          .from('group_roles')
          .select('permissions')
          .inFilter('id', roleIds);
      for (final r in (roleRows as List)) {
        perms.addAll(((r['permissions'] as List?) ?? const [])
            .map((e) => e as String));
      }
    }
    return perms.toList();
  }

  Future<List<GroupRole>> fetchRoles(String groupId) async {
    final roleRows = await _client
        .from('group_roles')
        .select('id, name, permissions, is_system')
        .eq('group_id', groupId)
        .order('rank');
    final roles = (roleRows as List).cast<Map<String, dynamic>>();
    if (roles.isEmpty) return [];

    final roleIds = roles.map((r) => r['id'] as String).toList();
    final mrRows = await _client
        .from('group_member_roles')
        .select('role_id')
        .inFilter('role_id', roleIds);
    final countByRole = <String, int>{};
    for (final r in (mrRows as List)) {
      final rid = r['role_id'] as String;
      countByRole[rid] = (countByRole[rid] ?? 0) + 1;
    }

    return roles.map((r) {
      return GroupRole(
        id: r['id'] as String,
        name: r['name'] as String,
        permissions: ((r['permissions'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        isSystem: r['is_system'] == true,
        memberCount: countByRole[r['id'] as String] ?? 0,
      );
    }).toList();
  }

  Future<List<GroupMember>> fetchMembers(String groupId) async {
    final memberRows = await _client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId)
        .eq('status', 'active');
    final memberIds = (memberRows as List)
        .map((r) => r['user_id'] as String)
        .toList();
    if (memberIds.isEmpty) return [];

    final profileRows = await _client
        .from('profiles_public')
        .select('id, display_name, course')
        .inFilter('id', memberIds);
    final names = <String, String>{};
    final courses = <String, String>{};
    for (final p in (profileRows as List)) {
      names[p['id'] as String] = (p['display_name'] as String?) ?? 'Estudante UFV';
      courses[p['id'] as String] = (p['course'] as String?) ?? '';
    }

    final mrRows = await _client
        .from('group_member_roles')
        .select('user_id, role_id')
        .eq('group_id', groupId)
        .inFilter('user_id', memberIds);
    final roleIdsByUser = <String, List<String>>{};
    final roleIds = <String>[];
    for (final r in (mrRows as List)) {
      final uid = r['user_id'] as String;
      final rid = r['role_id'] as String;
      roleIdsByUser.putIfAbsent(uid, () => []).add(rid);
      roleIds.add(rid);
    }

    final roleMap = <String, GroupRole>{};
    if (roleIds.isNotEmpty) {
      final roleRows = await _client
          .from('group_roles')
          .select('id, name, permissions, is_system')
          .inFilter('id', roleIds.toSet().toList());
      for (final r in (roleRows as List)) {
        roleMap[r['id'] as String] = GroupRole(
          id: r['id'] as String,
          name: r['name'] as String,
          permissions: ((r['permissions'] as List?) ?? const [])
              .map((e) => e as String)
              .toList(),
          isSystem: r['is_system'] == true,
        );
      }
    }

    return memberIds.map((uid) {
      return GroupMember(
        userId: uid,
        name: names[uid] ?? 'Estudante UFV',
        course: courses[uid] ?? '',
        roles: (roleIdsByUser[uid] ?? const [])
            .map((rid) => roleMap[rid])
            .whereType<GroupRole>()
            .toList(),
      );
    }).toList();
  }

  Future<List<GroupInvite>> fetchInvites(String groupId) async {
    final rows = await _client
        .from('group_invites')
        .select('id, expires_at, max_uses, used_count, revoked_at')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) {
      return GroupInvite(
        id: r['id'] as String,
        expiresAt: DateTime.parse(r['expires_at'] as String),
        maxUses: r['max_uses'] as int,
        usedCount: r['used_count'] as int,
        revoked: r['revoked_at'] != null,
      );
    }).toList();
  }

  Future<List<String>> fetchFollowers(String groupId) async {
    final rows = await _client
        .from('group_followers')
        .select('user_id')
        .eq('group_id', groupId);
    final ids = (rows as List).map((r) => r['user_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profileRows = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', ids);
    final names = <String, String>{};
    for (final p in (profileRows as List)) {
      names[p['id'] as String] = (p['display_name'] as String?) ?? 'Estudante UFV';
    }
    return ids.map((id) => names[id] ?? 'Estudante UFV').toList();
  }

  Future<List<GroupSummary>> fetchDirectory({String? search}) async {
    final rows = await _client.rpc(
      'public_group_directory',
      params: {'p_search': search ?? ''},
    );
    return (rows as List).map((r) {
      return GroupSummary(
        id: r['id'] as String,
        name: r['name'] as String,
        description: r['description'] as String?,
        category: (r['category'] as String?) ?? 'Outros',
        campus: (r['campus'] as String?) ?? 'Viçosa',
        isOfficial: r['is_official'] == true,
        memberCount: (r['member_count'] as int?) ?? 0,
        followerCount: (r['follower_count'] as int?) ?? 0,
      );
    }).toList();
  }

  Future<List<GroupSummary>> fetchPendingGroups() async {
    final rows = await _client
        .from('groups')
        .select('id, name, description, category, campus, is_official')
        .eq('visibility', 'public')
        .eq('public_approval', 'pending');
    return (rows as List).map((r) {
      return GroupSummary(
        id: r['id'] as String,
        name: r['name'] as String,
        description: r['description'] as String?,
        category: (r['category'] as String?) ?? 'Outros',
        campus: (r['campus'] as String?) ?? 'Viçosa',
        isOfficial: r['is_official'] == true,
      );
    }).toList();
  }

  Future<String> createGroup({
    required String name,
    String? description,
    String? category,
    String? campus,
    String? course,
    String visibility = 'private',
  }) async {
    final res = await _client.rpc('create_group', params: {
      'p_name': name.trim(),
      'p_description': description,
      'p_category': category,
      'p_campus': campus,
      'p_course': course,
      'p_visibility': visibility,
    });
    return (res as Map)['id'] as String;
  }

  Future<void> updateGroup(
    String id, {
    required String name,
    String? description,
    String? category,
    String? campus,
    String? course,
  }) async {
    await _client.rpc('update_group', params: {
      'p_group_id': id,
      'p_name': name.trim(),
      'p_description': description,
      'p_category': category,
      'p_campus': campus,
      'p_course': course,
    });
  }

  Future<void> requestPublicGroup(String id) async {
    await _client.rpc('request_public_group', params: {'p_group_id': id});
  }

  Future<void> joinGroup(String id) async {
    await _client.rpc('join_group', params: {'p_group_id': id});
  }

  Future<void> leaveGroup(String id) async {
    await _client.rpc('leave_group', params: {'p_group_id': id});
  }

  Future<void> followGroup(String id) async {
    await _client.rpc('follow_group', params: {'p_group_id': id});
  }

  Future<void> unfollowGroup(String id) async {
    await _client.rpc('unfollow_group', params: {'p_group_id': id});
  }

  Future<String> createRole(String groupId, String name, List<String> permissions) async {
    final res = await _client.rpc('create_group_role', params: {
      'p_group_id': groupId,
      'p_name': name.trim(),
      'p_permissions': permissions,
    });
    return res as String;
  }

  Future<void> updateRole(String roleId, String name, List<String> permissions) async {
    await _client.rpc('update_group_role', params: {
      'p_role_id': roleId,
      'p_name': name.trim(),
      'p_permissions': permissions,
    });
  }

  Future<void> deleteRole(String roleId) async {
    await _client.rpc('delete_group_role', params: {'p_role_id': roleId});
  }

  Future<void> assignRole(String groupId, String userId, String roleId) async {
    await _client.rpc('assign_group_role', params: {
      'p_group_id': groupId,
      'p_user_id': userId,
      'p_role_id': roleId,
    });
  }

  Future<void> removeRole(String groupId, String userId, String roleId) async {
    await _client.rpc('remove_group_role', params: {
      'p_group_id': groupId,
      'p_user_id': userId,
      'p_role_id': roleId,
    });
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _client.rpc('remove_group_member', params: {
      'p_group_id': groupId,
      'p_user_id': userId,
    });
  }

  Future<String> redeemInvite(String token) async {
    final res = await _client.rpc(
      'redeem_group_invite',
      params: {'p_token': token},
    );
    return res as String;
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.rpc('delete_group', params: {'p_group_id': groupId});
  }

  Future<void> moderatePost(String postId, String action) async {
    await _client.rpc('group_moderate_post', params: {
      'p_post_id': postId,
      'p_action': action,
    });
  }

  Future<void> moderateComment(String commentId, String action) async {
    await _client.rpc('group_moderate_comment', params: {
      'p_comment_id': commentId,
      'p_action': action,
    });
  }

  Future<bool> hasPermission(String groupId, String permission) async {
    final res = await _client.rpc(
      'has_group_permission',
      params: {'g': groupId, 'p': permission},
    );
    return res == true;
  }

  Future<({String id, String token, DateTime expiresAt, int maxUses})>
      createInvite(String groupId, {Duration validFor = const Duration(days: 7), int maxUses = 1}) async {
    final res = await _client.rpc('create_group_invite', params: {
      'p_group_id': groupId,
      'p_expires_at': DateTime.now().toUtc().add(validFor).toIso8601String(),
      'p_max_uses': maxUses,
    });
    final map = (res as Map).cast<String, dynamic>();
    return (
      id: map['id'] as String,
      token: map['token'] as String,
      expiresAt: DateTime.parse(map['expires_at'] as String),
      maxUses: map['max_uses'] as int,
    );
  }

  Future<void> revokeInvite(String inviteId) async {
    await _client.rpc('revoke_group_invite', params: {'p_invite_id': inviteId});
  }

  Future<void> reviewGroup(String id, bool approve, {String? note}) async {
    await _client.rpc('admin_review_group', params: {
      'p_group_id': id,
      'p_approve': approve,
      'p_note': note,
    });
  }
}
