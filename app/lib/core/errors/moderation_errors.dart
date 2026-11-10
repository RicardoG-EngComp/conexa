import 'package:supabase_flutter/supabase_flutter.dart';

bool needsGuidelinesAcceptance(Object error) {
  return error is PostgrestException &&
      error.message.contains('diretrizes_necessarias');
}

String friendlyModerationError(
  Object error, {
  String fallback = 'Nao foi possivel concluir.',
}) {
  if (error is PostgrestException) {
    final message = error.message;
    if (message.contains('conteudo_proibido')) {
      return 'Conteudo bloqueado pelas Diretrizes da Comunidade.';
    }
    if (message.contains('diretrizes_necessarias')) {
      return 'Aceite as Diretrizes da Comunidade para continuar.';
    }
    if (message.contains('conta_inativa')) {
      return 'Sua conta esta suspensa ou banida.';
    }
  }
  return fallback;
}
