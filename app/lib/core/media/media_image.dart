import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import 'media_cache.dart';
import 'media_models.dart';
import 'media_providers.dart';

class MediaImage extends ConsumerWidget {
  const MediaImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.useThumb = true,
    this.borderRadius = BorderRadius.zero,
    this.backgroundColor,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool useThumb;
  final BorderRadius borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (path.isEmpty) return _placeholder();

    final variantsAsync = ref.watch(mediaVariantsProvider(path));
    return variantsAsync.when(
      data: (variants) {
        if (variants == null) return _placeholder();
        return _buildImage(context, variants);
      },
      loading: _placeholder,
      error: (_, _) => _placeholder(),
    );
  }

  Widget _buildImage(BuildContext context, MediaVariants variants) {
    final url = useThumb ? variants.thumb : variants.full;
    final targetWidth = width;
    final memCacheWidth = targetWidth == null || !targetWidth.isFinite
        ? null
        : (targetWidth * MediaQuery.devicePixelRatioOf(context)).round();

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: url,
        cacheKey: useThumb ? '$path#t' : '$path#f',
        cacheManager: mediaCacheManager,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) {
          if (useThumb && variants.full.isNotEmpty && variants.full != url) {
            return CachedNetworkImage(
              imageUrl: variants.full,
              cacheKey: '$path#f',
              cacheManager: mediaCacheManager,
              width: width,
              height: height,
              fit: fit,
              memCacheWidth: memCacheWidth,
              placeholder: (_, _) => _placeholder(),
              errorWidget: (_, _, _) => _placeholder(),
            );
          }
          return _placeholder();
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? AppColors.border,
    );
  }
}
