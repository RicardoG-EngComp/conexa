import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/qa_media_service.dart';
import '../data/study_models.dart';

class QaAttachmentView extends ConsumerWidget {
  const QaAttachmentView({super.key, required this.attachment});

  final QaAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(qaMediaVariantsProvider(attachment.path));
    return async.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const Icon(Icons.broken_image_outlined),
      data: (variants) {
        if (variants == null) {
          return const Icon(Icons.attachment_outlined);
        }
        if (attachment.kind == 'image') {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CachedNetworkImage(
              imageUrl: variants.full,
              fit: BoxFit.cover,
              placeholder: (_, _) => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
            ),
          );
        }
        return OutlinedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(variants.full),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            attachment.name ?? 'Abrir PDF',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
