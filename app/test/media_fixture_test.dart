import 'package:conexa/core/media/image_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('fixtures: WebP reduz o payload sem upscale', () async {
    final fixtures = <String, img.Image>{
      'gradiente': _gradient(2000, 1500),
      'baixa_luz': _lowLight(1600, 2000),
      'alto_detalhe': _checker(1800, 1200),
    };

    for (final entry in fixtures.entries) {
      final png = img.encodePng(entry.value);
      final processed = await ImageProcessor.profileImage(png, avatar: false);

      final decoded = img.decodeImage(png)!;
      final resized = img.copyResize(decoded, width: 1280);
      final jpeg = img.encodeJpg(resized, quality: 85);

      // ignore: avoid_print
      print(
        '${entry.key}: origem=${png.length}B '
        'webp=${processed.full.length}B '
        'jpeg85=${jpeg.length}B '
        'thumb=${processed.thumb.length}B '
        '${processed.width}x${processed.height}',
      );

      expect(processed.width, lessThanOrEqualTo(1280));
      expect(processed.thumb.length, lessThan(processed.full.length));
      expect(processed.full.length, lessThan(jpeg.length));
    }
  });
}

img.Image _gradient(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final r = (x * 255 ~/ width);
      final g = (y * 255 ~/ height);
      final b = ((x + y) * 255 ~/ (width + height));
      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return image;
}

img.Image _lowLight(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final base = 12 + ((x + y) % 40);
      image.setPixelRgb(x, y, base, base + 4, base + 10);
    }
  }
  return image;
}

img.Image _checker(int width, int height) {
  final image = img.Image(width: width, height: height);
  final cell = 40;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final on = ((x ~/ cell) + (y ~/ cell)).isEven;
      final value = on ? 235 : 20;
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return image;
}
