import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:conexa/core/media/image_processor.dart';
import 'package:conexa/core/utils/uuid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';
  final emailA = Platform.environment['TEST_USER_A_EMAIL'] ?? '';
  final passwordA = Platform.environment['TEST_USER_A_PASSWORD'] ?? '';

  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  Future<SupabaseClient> signedInA() async {
    final client = createSupabaseClient()!;
    await signInWithRetry(client, emailA, passwordA);
    return client;
  }

  Future<(int, Map<String, dynamic>)> upload(
    SupabaseClient client, {
    required Uint8List bytes,
    required String kind,
    required String variant,
    required String contentType,
    String? assetId,
  }) async {
    final token = client.auth.currentSession!.accessToken;
    final request = await HttpClient().postUrl(
      Uri.parse('$supabaseUrl/functions/v1/media-upload'),
    );
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.set('apikey', anonKey);
    request.headers.contentType = ContentType.parse(contentType);
    request.headers.set('x-kind', kind);
    request.headers.set('x-variant', variant);
    request.headers.set('x-width', '1');
    request.headers.set('x-height', '1');
    if (assetId != null) request.headers.set('x-asset-id', assetId);
    request.add(bytes);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final data = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;
    return (response.statusCode, data);
  }

  Future<int> getStatus(String url) async {
    final response = await (await HttpClient().getUrl(Uri.parse(url))).close();
    await response.drain<void>();
    return response.statusCode;
  }

  test(
    'R2: upload, assinatura, leitura e exclusao do proprio perfil',
    () async {
      final client = await signedInA();
      final userId = client.auth.currentUser!.id;
      String? key;

      try {
        final processed = await ImageProcessor.profileImage(png, avatar: true);
        final (status, uploaded) = await upload(
          client,
          bytes: processed.full,
          kind: 'avatar',
          variant: 'full',
          contentType: 'image/webp',
        );
        expect(status, 200, reason: uploaded.toString());
        key = uploaded['key'] as String?;
        expect(key, isNotNull);
        expect(key!, startsWith('$userId/'));
        expect(key, endsWith('.webp'));

        final (thumbStatus, thumbUploaded) = await upload(
          client,
          bytes: processed.thumb,
          kind: 'avatar',
          variant: 'thumb',
          contentType: 'image/webp',
          assetId: uploaded['assetId'] as String?,
        );
        expect(thumbStatus, 200, reason: thumbUploaded.toString());

        final signed = await client.functions.invoke(
          'media-sign',
          body: {
            'paths': [key],
          },
        );
        final signedData = signed.data as Map<String, dynamic>;
        final items = signedData['items'] as Map<String, dynamic>;
        final item = items[key] as Map<String, dynamic>?;
        expect(item, isNotNull);
        expect(await getStatus(item!['full'] as String), 200);
        expect(await getStatus(item['thumb'] as String), 200);

        final deleted = await client.functions.invoke(
          'media-delete',
          body: {
            'scope': 'profile',
            'paths': [key],
          },
        );
        final deleteData = deleted.data as Map<String, dynamic>;
        expect(deleteData['deleted'], 2);
        expect(await getStatus(item['full'] as String), 404);

        key = null;
      } finally {
        if (key != null) {
          try {
            await client.functions.invoke(
              'media-delete',
              body: {
                'scope': 'profile',
                'paths': [key],
              },
            );
          } catch (_) {}
        }
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'R2: uploader envia PDF de estudo e apaga do bucket de estudo',
    () async {
      final client = await signedInA();
      final userId = client.auth.currentUser!.id;
      String? key;

      try {
        final pdf = Uint8List.fromList(
          utf8.encode(
            '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n',
          ),
        );
        final (status, uploaded) = await upload(
          client,
          bytes: pdf,
          kind: 'study_pdf',
          variant: 'full',
          contentType: 'application/pdf',
        );
        expect(status, 200, reason: uploaded.toString());
        key = uploaded['key'] as String?;
        expect(key, isNotNull);
        expect(key!, startsWith('$userId/study/'));

        final deleted = await client.functions.invoke(
          'media-delete',
          body: {
            'scope': 'study',
            'paths': [key],
          },
        );
        final deleteData = deleted.data as Map<String, dynamic>;
        expect(deleteData['deleted'], greaterThanOrEqualTo(1));
        key = null;
      } finally {
        if (key != null) {
          try {
            await client.functions.invoke(
              'media-delete',
              body: {
                'scope': 'study',
                'paths': [key],
              },
            );
          } catch (_) {}
        }
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'R2: study-file-url assina PDF do autor e o material pendente',
    () async {
      final client = await signedInA();
      final userId = client.auth.currentUser!.id;
      final discipline = await client
          .from('disciplines')
          .select('id')
          .limit(1)
          .maybeSingle();
      if (discipline == null) return;

      final materialId = uuidV4();
      String? key;
      var materialCreated = false;

      try {
        final pdf = Uint8List.fromList(
          utf8.encode(
            '%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n',
          ),
        );
        final (status, uploaded) = await upload(
          client,
          bytes: pdf,
          kind: 'study_pdf',
          variant: 'full',
          contentType: 'application/pdf',
        );
        expect(status, 200, reason: uploaded.toString());
        key = uploaded['key'] as String?;
        expect(key, isNotNull);

        await client.from('study_materials').insert({
          'id': materialId,
          'discipline_id': discipline['id'],
          'author_id': userId,
          'title': 'Teste midia R2',
          'kind': 'pdf',
          'storage_path': key,
          'status': 'pending',
          'consent_version': '2026-11-upload',
        });
        materialCreated = true;

        final signed = await client.functions.invoke(
          'study-file-url',
          body: {'material_id': materialId},
        );
        final signedData = signed.data as Map<String, dynamic>;
        final url = signedData['url'] as String?;
        expect(url, isNotNull);
        expect(await getStatus(url!), 200);
      } finally {
        if (materialCreated) {
          try {
            await client.from('study_materials').delete().eq('id', materialId);
          } catch (_) {}
        }
        if (key != null) {
          try {
            await client.functions.invoke(
              'media-delete',
              body: {
                'scope': 'study',
                'paths': [key],
              },
            );
          } catch (_) {}
        }
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'compatibilidade: foto antiga no Supabase continua assinando',
    () async {
      final client = await signedInA();
      final userId = client.auth.currentUser!.id;
      final path = '$userId/legacy-${uuidV4()}.png';

      try {
        await client.storage
            .from('profile-media')
            .uploadBinary(
              path,
              png,
              fileOptions: const FileOptions(
                contentType: 'image/png',
                upsert: true,
              ),
            );

        final signed = await client.functions.invoke(
          'media-sign',
          body: {
            'paths': [path],
          },
        );
        final signedData = signed.data as Map<String, dynamic>;
        final items = signedData['items'] as Map<String, dynamic>;
        final item = items[path] as Map<String, dynamic>?;
        expect(item, isNotNull);
        expect(item!['backend'], 'supabase');
        expect(signedData['expiresIn'], 3600);
        expect(await getStatus(item['full'] as String), 200);
      } finally {
        try {
          await client.storage.from('profile-media').remove([path]);
        } catch (_) {}
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'R2: tipo declarado precisa bater com o conteudo',
    () async {
      final client = await signedInA();
      final (status, data) = await upload(
        client,
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        kind: 'avatar',
        variant: 'full',
        contentType: 'image/png',
      );
      expect(status, 415, reason: data.toString());
      expect(data['error'], 'conteudo_nao_confere_com_tipo');
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'R2: nao assina nem apaga caminho de outro usuario',
    () async {
      final client = await signedInA();
      final userB = Platform.environment['TEST_USER_B_ID'];
      final foreign = userB == null
          ? '00000000-0000-4000-8000-000000000000/avatar/x.png'
          : '$userB/avatar/x.png';

      final signed = await client.functions.invoke(
        'media-sign',
        body: {
          'paths': [foreign],
        },
      );
      final signedData = signed.data as Map<String, dynamic>;
      expect(signedData['allowed'], 0);
      expect((signedData['items'] as Map).isEmpty, isTrue);

      final deleted = await client.functions.invoke(
        'media-delete',
        body: {
          'scope': 'profile',
          'paths': [foreign],
        },
      );
      final deleteData = deleted.data as Map<String, dynamic>;
      expect(deleteData['deleted'], 0);
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
