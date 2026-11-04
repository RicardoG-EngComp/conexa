class StickerPack {
  const StickerPack({
    required this.id,
    required this.name,
    required this.isPublic,
    required this.source,
  });

  final String id;
  final String name;
  final bool isPublic;
  final String source;

  factory StickerPack.fromMap(Map<String, dynamic> map) {
    return StickerPack(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'Pacote',
      isPublic: (map['is_public'] as bool?) ?? false,
      source: (map['source'] as String?) ?? 'user',
    );
  }
}

class StickerItem {
  const StickerItem({
    required this.id,
    required this.packId,
    required this.imagePath,
    this.emoji,
  });

  final String id;
  final String packId;
  final String imagePath;
  final String? emoji;

  factory StickerItem.fromMap(Map<String, dynamic> map) {
    return StickerItem(
      id: map['id'] as String,
      packId: map['pack_id'] as String,
      imagePath: map['image_path'] as String,
      emoji: map['emoji'] as String?,
    );
  }
}

class GiphyItem {
  const GiphyItem({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.originalUrl,
  });

  final String id;
  final String title;
  final String previewUrl;
  final String originalUrl;

  factory GiphyItem.fromMap(Map<String, dynamic> map) {
    return GiphyItem(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      previewUrl: (map['preview'] as String?) ?? '',
      originalUrl: (map['original'] as String?) ?? '',
    );
  }
}
