enum FeedbackKind { bug, suggestion }

const Map<String, String> bugStatusOptions = {
  'new': 'Recebido',
  'triaged': 'Em análise',
  'in_progress': 'Em andamento',
  'fixed': 'Corrigido',
  'wontfix': 'Não será corrigido',
};

const Map<String, String> suggestionStatusOptions = {
  'new': 'Recebido',
  'analyzed': 'Em análise',
  'accepted': 'Aceito',
  'declined': 'Não será implementado',
  'implemented': 'Implementado',
};

Map<String, String> statusOptionsFor(FeedbackKind kind) =>
    kind == FeedbackKind.bug ? bugStatusOptions : suggestionStatusOptions;

class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.number,
    required this.kind,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.steps,
    this.expected,
    this.actual,
    this.problem,
    this.proposal,
    this.impact,
    this.platform,
    this.appVersion,
    this.screenshotPath,
  });

  final String id;
  final int number;
  final FeedbackKind kind;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;
  final String? steps;
  final String? expected;
  final String? actual;
  final String? problem;
  final String? proposal;
  final String? impact;
  final String? platform;
  final String? appVersion;
  final String? screenshotPath;

  String get protocol {
    final prefix = kind == FeedbackKind.bug ? 'BUG' : 'SUG';
    return '$prefix-${number.toString().padLeft(6, '0')}';
  }

  String get statusLabel => statusOptionsFor(kind)[status] ?? status;

  factory FeedbackEntry.fromBug(Map<String, dynamic> map) {
    return FeedbackEntry(
      id: map['id'] as String,
      number: (map['number'] as num).toInt(),
      kind: FeedbackKind.bug,
      title: map['title'] as String,
      description: map['description'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      steps: map['steps'] as String?,
      expected: map['expected'] as String?,
      actual: map['actual'] as String?,
      platform: map['platform'] as String?,
      appVersion: map['app_version'] as String?,
      screenshotPath: map['screenshot_path'] as String?,
    );
  }

  factory FeedbackEntry.fromSuggestion(Map<String, dynamic> map) {
    return FeedbackEntry(
      id: map['id'] as String,
      number: (map['number'] as num).toInt(),
      kind: FeedbackKind.suggestion,
      title: map['title'] as String,
      description: map['description'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      problem: map['problem'] as String?,
      proposal: map['proposal'] as String?,
      impact: map['impact'] as String?,
      platform: map['platform'] as String?,
      appVersion: map['app_version'] as String?,
    );
  }
}
