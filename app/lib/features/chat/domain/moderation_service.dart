class ModerationResult {
  const ModerationResult({required this.flagged, this.reason});

  final bool flagged;
  final String? reason;
}

/// Primeira versao da moderacao (heuristica).
/// Pode ser substituida por um modelo on-device sem mudar a interface.
class ModerationService {
  static final List<RegExp> _patterns = [
    RegExp(
      r'\b(vou te matar|vou te bater|vou te estuprar|vou acabar com voce|sei onde voce mora|vou te pegar)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(vagabunda|vadia|piranha|otaria|retardado|imbecil|lixo humano|nojenta|nojento)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(manda nude|manda foto pelada|quero ver seu corpo|manda uma foto sem roupa)\b',
      caseSensitive: false,
    ),
  ];

  ModerationResult check(String text) {
    final normalized = text.toLowerCase().trim();
    for (final pattern in _patterns) {
      if (pattern.hasMatch(normalized)) {
        return const ModerationResult(
          flagged: true,
          reason: 'Esta mensagem pode ser interpretada como assedio ou ofensa.',
        );
      }
    }
    return const ModerationResult(flagged: false);
  }
}
