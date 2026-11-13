import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'media_models.dart';

class ImageProcessor {
  ImageProcessor._();

  static Future<ProcessedImage> profileImage(
    Uint8List bytes, {
    required bool avatar,
  }) async {
    final result = await compute(_process, <String, dynamic>{
      'bytes': bytes,
      'fullSize': avatar ? 512 : 1280,
      'thumbSize': avatar ? 160 : 480,
      'fullQuality': 85,
      'thumbQuality': 80,
    });
    return ProcessedImage.fromMap(result);
  }

  static Future<ProcessedImage> studyImage(Uint8List bytes) async {
    final result = await compute(_process, <String, dynamic>{
      'bytes': bytes,
      'fullSize': 1600,
      'thumbSize': 480,
      'fullQuality': 85,
      'thumbQuality': 80,
    });
    return ProcessedImage.fromMap(result);
  }
}

Map<String, dynamic> _process(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('imagem_invalida');
  }

  final oriented = img.bakeOrientation(decoded);
  final full = _resize(oriented, args['fullSize'] as int);
  final thumb = _resize(oriented, args['thumbSize'] as int);

  return <String, dynamic>{
    'full': img.encodeWebP(
      full,
      lossless: false,
      quality: args['fullQuality'] as int,
    ),
    'thumb': img.encodeWebP(
      thumb,
      lossless: false,
      quality: args['thumbQuality'] as int,
    ),
    'width': full.width,
    'height': full.height,
    'thumbWidth': thumb.width,
    'thumbHeight': thumb.height,
  };
}

img.Image _resize(img.Image source, int maxSize) {
  final maxDim = math.max(source.width, source.height);
  if (maxDim <= maxSize) return source;

  return img.copyResize(
    source,
    width: source.width >= source.height ? maxSize : null,
    height: source.height > source.width ? maxSize : null,
    interpolation: img.Interpolation.average,
  );
}
