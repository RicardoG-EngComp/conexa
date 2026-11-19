class CampusEvent {
  const CampusEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.description,
    this.endsAt,
    this.location,
    this.ticketUrl,
    this.imageUrl,
    this.organizer,
    this.campus,
    this.course,
    this.tags = const [],
    this.status = 'approved',
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? description;
  final String? location;
  final String? ticketUrl;
  final String? imageUrl;
  final String? organizer;
  final String? campus;
  final String? course;
  final List<String> tags;
  final String status;

  factory CampusEvent.fromMap(Map<String, dynamic> map) {
    return CampusEvent(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      startsAt: DateTime.parse(map['starts_at'] as String),
      endsAt: map['ends_at'] == null
          ? null
          : DateTime.parse(map['ends_at'] as String),
      description: map['description'] as String?,
      location: map['location'] as String?,
      ticketUrl: map['ticket_url'] as String?,
      imageUrl: map['image_url'] as String?,
      organizer: map['organizer'] as String?,
      campus: map['campus'] as String?,
      course: map['course'] as String?,
      tags: ((map['tags'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      status: (map['status'] as String?) ?? 'approved',
    );
  }
}

class CampusPlace {
  const CampusPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.description,
    this.imageUrl,
    this.status = 'approved',
    this.createdBy,
  });

  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final String? description;
  final String? imageUrl;
  final String status;
  final String? createdBy;

  factory CampusPlace.fromMap(Map<String, dynamic> map) {
    return CampusPlace(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Outro',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      status: (map['status'] as String?) ?? 'approved',
      createdBy: map['created_by'] as String?,
    );
  }
}
