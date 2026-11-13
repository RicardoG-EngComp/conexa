import 'package:flutter_cache_manager/flutter_cache_manager.dart';

final mediaCacheManager = CacheManager(
  Config(
    'conexa_media_v1',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 500,
  ),
);

Future<void> clearMediaDiskCache() => mediaCacheManager.emptyCache();
