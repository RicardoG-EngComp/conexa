import 'package:conexa/core/media/image_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('gera WebP cheio e miniatura, sem upscale', () async {
    final source = img.Image(width: 2000, height: 1000);
    img.fill(source, color: img.ColorRgb8(40, 120, 180));
    final png = img.encodePng(source);

    final processed = await ImageProcessor.profileImage(png, avatar: false);

    expect(processed.width, 1280);
    expect(processed.height, 640);
    expect(processed.thumbWidth, 480);
    expect(processed.thumbHeight, 240);
    expect(String.fromCharCodes(processed.full.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(processed.full.sublist(8, 12)), 'WEBP');
    expect(processed.thumb.length, lessThan(processed.full.length));
  });

  test('avatar fica em 512 e nao aumenta imagem menor', () async {
    final small = img.Image(width: 300, height: 300);
    img.fill(small, color: img.ColorRgb8(200, 80, 40));

    final processed = await ImageProcessor.profileImage(
      img.encodePng(small),
      avatar: true,
    );

    expect(processed.width, 300);
    expect(processed.height, 300);
    expect(processed.thumbWidth, 160);
    expect(processed.thumbHeight, 160);
  });
}
