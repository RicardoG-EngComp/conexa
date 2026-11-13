import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyFeedbackError(
  Object error, {
  String fallback = 'Não foi possível enviar. Tente novamente.',
}) {
  if (error is PostgrestException) {
    final message = error.message;
    if (message.contains('limite_feedback')) {
      return 'Você atingiu o limite de 20 envios por dia. '
          'Tente novamente amanhã.';
    }
    if (message.contains('caminho_invalido')) {
      return 'O print anexado não pôde ser validado. Envie novamente.';
    }
    if (message.contains('forbidden')) {
      return 'Não foi possível validar sua conta. Entre novamente.';
    }
    if (message.contains('permission denied')) {
      return 'Este envio não é permitido.';
    }
  }
  if (error is StorageException) {
    return 'Não foi possível enviar o print. Tente novamente.';
  }
  return fallback;
}
