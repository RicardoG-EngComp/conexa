import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_info.dart';

class UpdateService {
  static const String updateUrl =
      'https://raw.githubusercontent.com/RicardoG-EngComp/tinder-de-republicas/main/update.json';

  Future<UpdateInfo?> check() async {
    try {
      final uri = Uri.parse(
        '$updateUrl?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(map);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      if (info.build > currentBuild) return info;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(info.apkUrl));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Falha no download (${response.statusCode})');
      }

      final total = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/match-update.apk');
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.close();

      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes).toString().toLowerCase();
      if (digest != info.sha256.toLowerCase()) {
        await file.delete();
        throw Exception('Hash do APK invalido.');
      }

      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        throw Exception('Nao foi possivel abrir o instalador.');
      }
    } finally {
      client.close();
    }
  }
}
