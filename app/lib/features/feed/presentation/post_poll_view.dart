import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/feed_providers.dart';
import '../data/feed_models.dart';

class PostPollView extends ConsumerWidget {
  const PostPollView({super.key, required this.poll});

  final FeedPoll poll;

  Future<void> _vote(
    BuildContext context,
    WidgetRef ref,
    String optionId,
  ) async {
    try {
      await ref.read(feedRepositoryProvider).votePoll(poll.id, optionId);
      ref.invalidate(feedForYouProvider);
      ref.invalidate(feedConnectionsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel votar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final total = poll.totalVotes;
    final closed = poll.isClosed;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final option in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: closed || poll.myOptionId != null
                    ? null
                    : () => _vote(context, ref, option.id),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: option.id == poll.myOptionId
                          ? AppColors.teal
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          if (poll.myOptionId != null || closed)
                            Text(
                              total == 0
                                  ? '0%'
                                  : '${((option.votes / total) * 100).round()}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                      if (poll.myOptionId != null || closed) ...[
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : option.votes / total,
                            minHeight: 4,
                            backgroundColor: AppColors.border,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            closed
                ? 'Enquete encerrada · $total voto(s)'
                : poll.myOptionId != null
                ? 'Voce votou · $total voto(s)'
                : 'Toque para votar · $total voto(s)',
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
