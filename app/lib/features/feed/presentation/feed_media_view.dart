import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/feed_media_service.dart';
import '../data/feed_models.dart';

class FeedMediaView extends ConsumerWidget {
  const FeedMediaView({super.key, required this.media});

  final List<FeedMedia> media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (media.isEmpty) return const SizedBox.shrink();
    if (media.first.isVideo) {
      return _MediaFrame(child: _FeedVideo(media: media.first));
    }

    if (media.length == 1) {
      return _MediaFrame(child: _FeedImage(media: media.first));
    }

    return _MediaFrame(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: [
          for (final item in media.take(4))
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: _FeedImage(media: item, fit: BoxFit.cover),
            ),
        ],
      ),
    );
  }
}

class _MediaFrame extends StatelessWidget {
  const _MediaFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        color: AppColors.paper,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _FeedImage extends ConsumerWidget {
  const _FeedImage({required this.media, this.fit = BoxFit.cover});

  final FeedMedia media;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feedMediaVariantsProvider(media.path));
    return AspectRatio(
      aspectRatio: _ratio(media.width, media.height),
      child: async.when(
        loading: () => const ColoredBox(
          color: AppColors.paper,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => const ColoredBox(
          color: AppColors.paper,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
        data: (variants) {
          if (variants == null) {
            return const ColoredBox(
              color: AppColors.paper,
              child: Center(child: Icon(Icons.image_not_supported_outlined)),
            );
          }
          return Semantics(
            label: media.altText ?? 'Imagem da publicacao',
            image: true,
            child: CachedNetworkImage(
              imageUrl: variants.full,
              fit: fit,
              placeholder: (_, _) => const ColoredBox(
                color: AppColors.paper,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, _, _) => ColoredBox(
                color: AppColors.paper,
                child: Center(
                  child: IconButton(
                    tooltip: 'Tentar novamente',
                    onPressed: () async {
                      await ref
                          .read(feedMediaServiceProvider)
                          .refresh(media.path);
                      ref.invalidate(feedMediaVariantsProvider(media.path));
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedVideo extends ConsumerWidget {
  const _FeedVideo({required this.media});

  final FeedMedia media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feedMediaVariantsProvider(media.path));
    final ratio = _ratio(media.width, media.height);
    return AspectRatio(
      aspectRatio: ratio,
      child: async.when(
        loading: () => const ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => const ColoredBox(
          color: Colors.black,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
        data: (variants) {
          if (variants == null) {
            return const ColoredBox(
              color: Colors.black,
              child: Center(child: Icon(Icons.videocam_off_outlined)),
            );
          }
          return Semantics(
            label: media.altText ?? 'Video da publicacao',
            button: true,
            child: GestureDetector(
              onTap: () => _openVideo(context, ref, media.path, variants.full),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  const Center(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white70,
                      child: Icon(Icons.play_arrow, size: 34),
                    ),
                  ),
                  if (media.durationMs != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _duration(media.durationMs!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openVideo(
    BuildContext context,
    WidgetRef ref,
    String path,
    String fallback,
  ) async {
    final variants = await ref.read(feedMediaServiceProvider).refresh(path);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => _VideoDialog(url: variants?.full ?? fallback),
    );
  }
}

class _VideoDialog extends StatefulWidget {
  const _VideoDialog({required this.url});

  final String url;

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _controller.play();
        })
        .catchError((_) {
          if (mounted) setState(() => _ready = false);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: AspectRatio(
        aspectRatio: _ready ? _controller.value.aspectRatio : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_ready)
              VideoPlayer(_controller)
            else
              const CircularProgressIndicator(),
            if (_ready)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 56,
                  color: Colors.white70,
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _ratio(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 16 / 9;
  }
  return width / height;
}

String _duration(int ms) {
  final total = (ms / 1000).round();
  final minutes = total ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
