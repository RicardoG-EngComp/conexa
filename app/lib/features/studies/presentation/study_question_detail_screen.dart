import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/errors/moderation_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../application/study_providers.dart';
import '../data/study_models.dart';
import 'qa_attachment_view.dart';

class StudyQuestionDetailScreen extends ConsumerStatefulWidget {
  const StudyQuestionDetailScreen({super.key, required this.questionId});

  final String questionId;

  @override
  ConsumerState<StudyQuestionDetailScreen> createState() =>
      _StudyQuestionDetailScreenState();
}

class _StudyQuestionDetailScreenState
    extends ConsumerState<StudyQuestionDetailScreen> {
  final _answer = TextEditingController();
  final _picker = ImagePicker();
  bool _sending = false;
  QaAttachmentDraft? _answerAttachment;

  Future<QaAttachmentDraft?> _pickAttachment() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Imagem'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (kind == null) return null;

    try {
      if (kind == 'image') {
        final picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (picked == null) return null;
        return await ref
            .read(studyRepositoryProvider)
            .uploadQaAttachment(
              bytes: await picked.readAsBytes(),
              image: true,
              name: picked.name,
            );
      }

      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (files.isEmpty) return null;
      final file = files.first;
      return await ref
          .read(studyRepositoryProvider)
          .uploadQaAttachment(
            bytes: await file.xFile.readAsBytes(),
            image: false,
            name: file.name,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel anexar.')),
        );
      }
      return null;
    }
  }

  Future<void> _attachQuestion(StudyQuestion question) async {
    final draft = await _pickAttachment();
    if (draft == null) return;
    try {
      await ref
          .read(studyRepositoryProvider)
          .addQuestionAttachment(question.id, draft);
      ref.invalidate(questionAttachmentsProvider(question.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel anexar.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _send(StudyQuestion question) async {
    final text = _answer.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final attachment = _answerAttachment;
      final answerId = await ref
          .read(studyRepositoryProvider)
          .createAnswer(question.id, text);
      if (attachment != null) {
        await ref
            .read(studyRepositoryProvider)
            .addAnswerAttachment(answerId, attachment);
      }
      _answer.clear();
      _answerAttachment = null;
      ref.invalidate(answersProvider(question.id));
      ref.invalidate(answerAttachmentsProvider(question.id));
      ref.invalidate(questionProvider(question.id));
      ref.invalidate(questionsProvider(question.disciplineId));
    } catch (error) {
      if (mounted) {
        if (needsGuidelinesAcceptance(error)) {
          await showGuidelinesConsentDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                friendlyModerationError(
                  error,
                  fallback: 'Nao foi possivel responder.',
                ),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _accept(StudyQuestion question, StudyAnswer answer) async {
    try {
      await ref.read(studyRepositoryProvider).acceptAnswer(answer.id);
      ref.invalidate(answersProvider(question.id));
      ref.invalidate(questionProvider(question.id));
      ref.invalidate(questionsProvider(question.disciplineId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel aceitar.')),
        );
      }
    }
  }

  Future<void> _vote(StudyQuestion question, StudyAnswer answer) async {
    try {
      await ref.read(studyRepositoryProvider).toggleAnswerVote(answer.id);
      ref.invalidate(answersProvider(question.id));
    } catch (_) {}
  }

  Future<void> _delete(StudyQuestion question, StudyAnswer answer) async {
    try {
      await ref.read(studyRepositoryProvider).deleteAnswer(answer.id);
      ref.invalidate(answersProvider(question.id));
      ref.invalidate(questionProvider(question.id));
      ref.invalidate(questionsProvider(question.disciplineId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel apagar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final questionAsync = ref.watch(questionProvider(widget.questionId));
    final answersAsync = ref.watch(answersProvider(widget.questionId));
    final questionAttachmentsAsync = ref.watch(
      questionAttachmentsProvider(widget.questionId),
    );
    final answerAttachmentsAsync = ref.watch(
      answerAttachmentsProvider(widget.questionId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Pergunta')),
      body: questionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Erro ao carregar pergunta.')),
        data: (question) {
          if (question == null) {
            return const Center(child: Text('Pergunta indisponivel.'));
          }
          final isAuthor = question.authorId == myId;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(question.title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${question.authorName ?? 'Aluno'} · '
                      '${timeAgo(question.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    if (question.status == 'resolved') ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Chip(
                        avatar: Icon(Icons.check_circle, size: 16),
                        label: Text('Resolvida'),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(question.content, style: theme.textTheme.bodyLarge),
                    if (questionAttachmentsAsync.asData?.value.isNotEmpty ==
                        true) ...[
                      const SizedBox(height: AppSpacing.md),
                      for (final attachment
                          in questionAttachmentsAsync.asData!.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: QaAttachmentView(attachment: attachment),
                        ),
                    ],
                    if (isAuthor) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _attachQuestion(question),
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Anexar imagem/PDF'),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Text('Respostas', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    answersAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) =>
                          const Text('Erro ao carregar respostas.'),
                      data: (answers) {
                        if (answers.isEmpty) {
                          return Text(
                            'Nenhuma resposta ainda.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final answer in answers)
                              _AnswerCard(
                                answer: answer,
                                attachments:
                                    answerAttachmentsAsync.asData?.value[answer
                                        .id] ??
                                    const [],
                                canAccept: isAuthor && !answer.accepted,
                                canDelete: answer.authorId == myId || isAuthor,
                                onVote: () => _vote(question, answer),
                                onAccept: () => _accept(question, answer),
                                onDelete: () => _delete(question, answer),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_answerAttachment != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: InputChip(
                            avatar: Icon(
                              _answerAttachment!.kind == 'image'
                                  ? Icons.image_outlined
                                  : Icons.picture_as_pdf_outlined,
                              size: 16,
                            ),
                            label: Text(
                              _answerAttachment!.name ?? 'Anexo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () =>
                                setState(() => _answerAttachment = null),
                          ),
                        ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Anexar imagem/PDF',
                            onPressed: _sending
                                ? null
                                : () async {
                                    final draft = await _pickAttachment();
                                    if (draft != null && mounted) {
                                      setState(() => _answerAttachment = draft);
                                    }
                                  },
                            icon: const Icon(Icons.attach_file),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _answer,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Escreva uma resposta...',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton.filled(
                            onPressed: _sending ? null : () => _send(question),
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.attachments,
    required this.canAccept,
    required this.canDelete,
    required this.onVote,
    required this.onAccept,
    required this.onDelete,
  });

  final StudyAnswer answer;
  final List<QaAttachment> attachments;
  final bool canAccept;
  final bool canDelete;
  final VoidCallback onVote;
  final VoidCallback onAccept;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: answer.accepted
            ? AppColors.teal.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: answer.accepted ? AppColors.teal : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  answer.authorName ?? 'Aluno',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (answer.accepted)
                Icon(Icons.check_circle, size: 18, color: AppColors.teal),
            ],
          ),
          Text(
            timeAgo(answer.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(answer.content),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final attachment in attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: QaAttachmentView(attachment: attachment),
              ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                onPressed: onVote,
                icon: Icon(
                  answer.votedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 16,
                ),
                label: Text('${answer.votes}'),
              ),
              if (canAccept)
                TextButton(onPressed: onAccept, child: const Text('Aceitar')),
              if (canDelete)
                TextButton(onPressed: onDelete, child: const Text('Apagar')),
            ],
          ),
        ],
      ),
    );
  }
}
