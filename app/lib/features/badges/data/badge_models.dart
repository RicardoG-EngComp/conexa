class ProfileBadge {
  const ProfileBadge({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.icon = 'military_tech',
    this.color = '#0F5C5C',
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String icon;
  final String color;

  factory ProfileBadge.fromMap(Map<String, dynamic> map) {
    return ProfileBadge(
      id: map['id'] as String,
      slug: (map['slug'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Insignia',
      description: map['description'] as String?,
      icon: (map['icon'] as String?) ?? 'military_tech',
      color: (map['color'] as String?) ?? '#0F5C5C',
    );
  }
}
