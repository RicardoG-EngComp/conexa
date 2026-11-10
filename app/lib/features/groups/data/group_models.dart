class UserGroupRole {
  const UserGroupRole({
    required this.id,
    required this.name,
    this.permissions = const [],
  });

  final String id;
  final String name;
  final List<String> permissions;
}

class UserGroup {
  const UserGroup({
    required this.id,
    required this.name,
    required this.isOfficial,
    required this.isPublicVerified,
    this.roles = const [],
  });

  final String id;
  final String name;
  final bool isOfficial;
  final bool isPublicVerified;
  final List<UserGroupRole> roles;

  bool get canPostAsGroup =>
      roles.any((r) => r.permissions.contains('post_as_group'));
}

class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.campus,
    required this.isOfficial,
    this.description,
    this.memberCount = 0,
    this.followerCount = 0,
  });

  final String id;
  final String name;
  final String category;
  final String campus;
  final bool isOfficial;
  final String? description;
  final int memberCount;
  final int followerCount;
}

class GroupRole {
  const GroupRole({
    required this.id,
    required this.name,
    this.permissions = const [],
    this.isSystem = false,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final List<String> permissions;
  final bool isSystem;
  final int memberCount;
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.name,
    required this.course,
    this.roles = const [],
  });

  final String userId;
  final String name;
  final String course;
  final List<GroupRole> roles;
}

enum GroupInviteStatus { active, expired, revoked, usedUp }

class GroupInvite {
  const GroupInvite({
    required this.id,
    required this.expiresAt,
    required this.maxUses,
    required this.usedCount,
    this.revoked = false,
  });

  final String id;
  final DateTime expiresAt;
  final int maxUses;
  final int usedCount;
  final bool revoked;

  GroupInviteStatus get status {
    if (revoked) return GroupInviteStatus.revoked;
    if (usedCount >= maxUses) return GroupInviteStatus.usedUp;
    if (expiresAt.isBefore(DateTime.now())) return GroupInviteStatus.expired;
    return GroupInviteStatus.active;
  }
}

class GroupDetail {
  const GroupDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.campus,
    required this.visibility,
    required this.publicApproval,
    required this.isOfficial,
    required this.ownerId,
    this.description,
    this.course,
    this.isMember = false,
    this.isFollowing = false,
    this.memberCount = 0,
    this.followerCount = 0,
    this.permissions = const [],
  });

  final String id;
  final String name;
  final String category;
  final String campus;
  final String visibility;
  final String publicApproval;
  final bool isOfficial;
  final String ownerId;
  final String? description;
  final String? course;
  final bool isMember;
  final bool isFollowing;
  final int memberCount;
  final int followerCount;
  final List<String> permissions;

  bool get isPublicApproved =>
      visibility == 'public' && publicApproval == 'approved' && isOfficial;
  bool get pendingPublic =>
      visibility == 'public' && publicApproval == 'pending';
  bool get canManageGroup => permissions.contains('manage_group');
  bool get canManageRoles => permissions.contains('manage_roles');
  bool get canManageMembers => permissions.contains('manage_members');
  bool get canManageInvites => permissions.contains('manage_invites');
  bool get canPostAsGroup => permissions.contains('post_as_group');
  bool get canModerate => permissions.contains('moderate_content');
}
