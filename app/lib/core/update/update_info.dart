class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.build,
    required this.apkUrl,
    required this.sha256,
    required this.notes,
    required this.mandatory,
  });

  final String version;
  final int build;
  final String apkUrl;
  final String sha256;
  final String notes;
  final bool mandatory;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: (json['version'] as String?) ?? '',
      build: (json['build'] as num?)?.toInt() ?? 0,
      apkUrl: (json['apk_url'] as String?) ?? '',
      sha256: (json['sha256'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      mandatory: (json['mandatory'] as bool?) ?? true,
    );
  }
}
