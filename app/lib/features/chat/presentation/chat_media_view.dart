import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/chat_media_service.dart';
import '../data/chat_models.dart';

class ChatMediaView extends ConsumerWidget {
  const ChatMediaView({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = message.mediaPath;
    if (path == null) return const SizedBox.shrink();
    final async = ref.watch(chatMediaVariantsProvider(path));

    return async.when(
      loading: () => const SizedBox(
        width: 220,
        height: 140,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const Icon(Icons.broken_image_outlined),
      data: (variants) {
        if (variants == null) {
          return const Icon(Icons.image_not_supported_outlined);
        }
        if (message.kind == 'image') {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CachedNetworkImage(
              imageUrl: variants.thumb,
              width: 240,
              fit: BoxFit.cover,
              placeholder: (_, _) => const SizedBox(
                width: 240,
                height: 160,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, _, _) => IconButton(
                tooltip: 'Tentar novamente',
                onPressed: () async {
                  await ref
                      .read(chatMediaServiceProvider)
                      .refresh(message.mediaPath!);
                  ref.invalidate(chatMediaVariantsProvider(message.mediaPath!));
                },
                icon: const Icon(Icons.refresh),
              ),
            ),
          );
        }
        if (message.kind == 'video') {
          return GestureDetector(
            onTap: () => _openVideo(context, ref, path, variants.full),
            child: Container(
              width: 240,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Center(
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white70,
                  child: Icon(Icons.play_arrow, size: 30),
                ),
              ),
            ),
          );
        }
        return InkWell(
          onTap: () => launchUrl(
            Uri.parse(variants.full),
            mode: LaunchMode.externalApplication,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf_outlined),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.mediaName ?? 'Arquivo',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openVideo(
    BuildContext context,
    WidgetRef ref,
    String path,
    String fallback,
  ) async {
    final variants = await ref.read(chatMediaServiceProvider).refresh(path);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => _ChatVideoDialog(url: variants?.full ?? fallback),
    );
  }
}

class _ChatVideoDialog extends StatefulWidget {
  const _ChatVideoDialog({required this.url});

  final String url;

  @override
  State<_ChatVideoDialog> createState() => _ChatVideoDialogState();
}

class _ChatVideoDialogState extends State<_ChatVideoDialog> {
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
              IconButton(
                onPressed: () => setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                }),
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  color: Colors.white70,
                  size: 56,
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
