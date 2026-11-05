class Discipline {
  const Discipline({
    required this.id,
    required this.name,
    required this.campus,
    this.code,
    this.course,
  });

  final String id;
  final String name;
  final String campus;
  final String? code;
  final String? course;

  factory Discipline.fromMap(Map<String, dynamic> map) {
    return Discipline(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'Disciplina',
      campus: (map['campus'] as String?) ?? 'Viçosa',
      code: map['code'] as String?,
      course: map['course'] as String?,
    );
  }
}

class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.disciplineId,
    required this.authorId,
    required this.title,
    required this.kind,
    required this.status,
    required this.createdAt,
    this.description,
    this.storagePath,
    this.externalUrl,
    this.authorName,
    this.upvotes = 0,
    this.votedByMe = false,
  });

  final String id;
  final String disciplineId;
  final String authorId;
  final String title;
  final String kind;
  final String status;
  final DateTime createdAt;
  final String? description;
  final String? storagePath;
  final String? externalUrl;
  final String? authorName;
  final int upvotes;
  final bool votedByMe;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';

  StudyMaterial copyWith({
    String? authorName,
    int? upvotes,
    bool? votedByMe,
  }) {
    return StudyMaterial(
      id: id,
      disciplineId: disciplineId,
      authorId: authorId,
      title: title,
      kind: kind,
      status: status,
      createdAt: createdAt,
      description: description,
      storagePath: storagePath,
      externalUrl: externalUrl,
      authorName: authorName ?? this.authorName,
      upvotes: upvotes ?? this.upvotes,
      votedByMe: votedByMe ?? this.votedByMe,
    );
  }

  factory StudyMaterial.fromMap(Map<String, dynamic> map) {
    return StudyMaterial(
      id: map['id'] as String,
      disciplineId: map['discipline_id'] as String,
      authorId: map['author_id'] as String,
      title: (map['title'] as String?) ?? '',
      kind: (map['kind'] as String?) ?? 'link',
      status: (map['status'] as String?) ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
      description: map['description'] as String?,
      storagePath: map['storage_path'] as String?,
      externalUrl: map['external_url'] as String?,
    );
  }
}
