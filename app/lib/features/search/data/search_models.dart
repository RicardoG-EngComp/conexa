class StudySearchResults {
  const StudySearchResults({
    this.materials = const [],
    this.disciplines = const [],
    this.professors = const [],
    this.questions = const [],
  });

  final List<StudyMaterialResult> materials;
  final List<StudyDisciplineResult> disciplines;
  final List<StudyProfessorResult> professors;
  final List<StudyQuestionResult> questions;

  bool get isEmpty =>
      materials.isEmpty &&
      disciplines.isEmpty &&
      professors.isEmpty &&
      questions.isEmpty;

  factory StudySearchResults.fromMap(Map<String, dynamic> map) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) build) {
      final raw = (map[key] as List?) ?? const [];
      return raw
          .whereType<Map>()
          .map((item) => build(item.cast<String, dynamic>()))
          .toList();
    }

    return StudySearchResults(
      materials: parse('materials', StudyMaterialResult.fromMap),
      disciplines: parse('disciplines', StudyDisciplineResult.fromMap),
      professors: parse('professors', StudyProfessorResult.fromMap),
      questions: parse('questions', StudyQuestionResult.fromMap),
    );
  }
}

class StudyMaterialResult {
  const StudyMaterialResult({
    required this.id,
    required this.title,
    required this.kind,
    required this.disciplineId,
    required this.disciplineName,
    this.description,
    this.professorName,
    this.authorName,
  });

  final String id;
  final String title;
  final String kind;
  final String disciplineId;
  final String disciplineName;
  final String? description;
  final String? professorName;
  final String? authorName;

  factory StudyMaterialResult.fromMap(Map<String, dynamic> map) {
    return StudyMaterialResult(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      kind: (map['kind'] as String?) ?? 'link',
      disciplineId: (map['discipline_id'] as String?) ?? '',
      disciplineName: (map['discipline_name'] as String?) ?? '',
      description: map['description'] as String?,
      professorName: map['professor_name'] as String?,
      authorName: map['author_name'] as String?,
    );
  }
}

class StudyDisciplineResult {
  const StudyDisciplineResult({
    required this.id,
    required this.name,
    this.code,
    this.course,
    this.campus,
    this.professorName,
  });

  final String id;
  final String name;
  final String? code;
  final String? course;
  final String? campus;
  final String? professorName;

  factory StudyDisciplineResult.fromMap(Map<String, dynamic> map) {
    return StudyDisciplineResult(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      code: map['code'] as String?,
      course: map['course'] as String?,
      campus: map['campus'] as String?,
      professorName: map['professor_name'] as String?,
    );
  }
}

class StudyProfessorResult {
  const StudyProfessorResult({
    required this.name,
    this.disciplines = const [],
    this.courses = const [],
  });

  final String name;
  final List<String> disciplines;
  final List<String> courses;

  factory StudyProfessorResult.fromMap(Map<String, dynamic> map) {
    return StudyProfessorResult(
      name: (map['name'] as String?) ?? '',
      disciplines: ((map['disciplines'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      courses: ((map['courses'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }
}

class StudyQuestionResult {
  const StudyQuestionResult({
    required this.id,
    required this.title,
    required this.content,
    required this.disciplineId,
    required this.disciplineName,
    required this.status,
  });

  final String id;
  final String title;
  final String content;
  final String disciplineId;
  final String disciplineName;
  final String status;

  factory StudyQuestionResult.fromMap(Map<String, dynamic> map) {
    return StudyQuestionResult(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      disciplineId: (map['discipline_id'] as String?) ?? '',
      disciplineName: (map['discipline_name'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'open',
    );
  }
}
