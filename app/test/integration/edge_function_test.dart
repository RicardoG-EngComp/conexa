import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final functionUrl = Platform.environment['NOTIFICATION_FUNCTION_URL'] ?? '';
  final webhookSecret = Platform.environment['WEBHOOK_SECRET'] ?? '';
  final hasEdgeConfig = functionUrl.isNotEmpty && webhookSecret.isNotEmpty;

  test(
    'send-push responde 401 sem webhook secret',
    () async {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(functionUrl));
      req.headers.contentType = ContentType.json;
      final res = await req.close();
      expect(res.statusCode, 401);
      await res.drain();
      client.close();
    },
    skip: hasEdgeConfig ? null : 'Edge Function env not configured.',
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'send-push com webhook secret processa pendências',
    () async {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(functionUrl));
      req.headers.contentType = ContentType.json;
      req.headers.add('x-webhook-secret', webhookSecret);
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, lessThan(500));
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json.keys, contains('ok'));
      expect(json.keys, contains('processed'));
      client.close();
    },
    skip: hasEdgeConfig ? null : 'Edge Function env not configured.',
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
