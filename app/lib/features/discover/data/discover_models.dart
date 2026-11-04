class DiscoverProfile {
  const DiscoverProfile({
    required this.id,
    required this.displayName,
    required this.course,
    required this.campus,
    this.avatarPath,
  });

  final String id;
  final String displayName;
  final String course;
  final String campus;
  final String? avatarPath;

  factory DiscoverProfile.fromMap(Map<String, dynamic> map) {
    return DiscoverProfile(
      id: map['id'] as String,
      displayName: (map['display_name'] as String?) ?? 'UFV',
      course: (map['course'] as String?) ?? '',
      campus: (map['campus'] as String?) ?? '',
      avatarPath: map['avatar_url'] as String?,
    );
  }
}
