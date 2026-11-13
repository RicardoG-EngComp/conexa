import 'dart:typed_data';

class MediaVariants {
  const MediaVariants({required this.full, required this.thumb});

  final String full;
  final String thumb;
}

class MediaUploadResult {
  const MediaUploadResult({
    required this.key,
    required this.assetId,
    required this.bucket,
    required this.bytes,
    this.width,
    this.height,
  });

  final String key;
  final String assetId;
  final String bucket;
  final int bytes;
  final int? width;
  final int? height;

  factory MediaUploadResult.fromMap(Map<String, dynamic> map) {
    return MediaUploadResult(
      key: (map['key'] as String?) ?? '',
      assetId: (map['assetId'] as String?) ?? '',
      bucket: (map['bucket'] as String?) ?? '',
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
    );
  }
}

class ProcessedImage {
  const ProcessedImage({
    required this.full,
    required this.thumb,
    required this.width,
    required this.height,
    required this.thumbWidth,
    required this.thumbHeight,
  });

  final Uint8List full;
  final Uint8List thumb;
  final int width;
  final int height;
  final int thumbWidth;
  final int thumbHeight;

  factory ProcessedImage.fromMap(Map<String, dynamic> map) {
    return ProcessedImage(
      full: map['full'] as Uint8List,
      thumb: map['thumb'] as Uint8List,
      width: (map['width'] as num).toInt(),
      height: (map['height'] as num).toInt(),
      thumbWidth: (map['thumbWidth'] as num).toInt(),
      thumbHeight: (map['thumbHeight'] as num).toInt(),
    );
  }
}

class MediaException implements Exception {
  const MediaException(this.code, {this.status});

  final String code;
  final int? status;

  @override
  String toString() => status == null ? code : '$code ($status)';
}
