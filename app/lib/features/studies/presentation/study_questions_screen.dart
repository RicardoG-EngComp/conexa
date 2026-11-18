import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/moderation_errors.dart';
import '../../../core/errors/moderation_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_ago.dart';
import '../application/study_providers.dart';
import '../data/study_models.dart';

class StudyQuestionsScreen extends ConsumerStatefulWidget {
  const StudyQuestionsScreen({super.key, required this.disciplineId});

  final String disciplineId;

  @override
  ConsumerState<StudyQuestionsScreen> createState() =>
      _StudyQuestionsScreenState();
}

class _StudyQuestionsScreenState extends ConsumerState<StudyQuestionsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<StudyQuestion> _questions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _search.text.trim();
      final repo = ref.read(studyRepositoryProvider);
      final questions = query.isEmpty
          ? await repo.fetchQuestions(widget.disciplineId)
          : await repo.searchQuestions(widget.disciplineId, query);
      if (mounted) setState(() => _questions = questions);
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro ao carregar perguntas.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _ask() async {
    final title = TextEditingController();
    final content = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova pergunta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Titulo'),
              ),
              TextField(
                controller: content,
                minLines: 4,
                maxLines: 8,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Descreva a duvida',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().length < 5 ||
                  content.text.trim().length < 10) {
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    final t = title.text.trim();
    final c = content.text.trim();
    title.dispose();
    content.dispose();
    if (result != true) return;

    try {
      await ref
          .read(studyRepositoryProvider)
          .createQuestion(
            disciplineId: widget.disciplineId,
            title: t,
            content: c,
          );
      await _load();
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
                  fallback: 'Nao foi possivel publicar a pergunta.',
                ),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Perguntas da disciplina')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ask,
        icon: const Icon(Icons.help_outline),
        label: const Text('Perguntar'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Buscar perguntas...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _questions.isEmpty
                  ? Center(
                      child: Text(
                        _search.text.trim().isEmpty
                            ? 'Nenhuma pergunta ainda. Seja o primeiro.'
                            : 'Nenhuma pergunta encontrada.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      itemCount: _questions.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final question = _questions[index];
                        return Card(
                          child: ListTile(
                            title: Text(question.title),
                            subtitle: Text(
                              '${question.authorName ?? 'Aluno'} · '
                              '${question.answerCount} resposta(s) · '
                              '${timeAgo(question.createdAt)}',
                            ),
                            trailing: question.status == 'resolved'
                                ? Icon(
                                    Icons.check_circle,
                                    color: AppColors.teal,
                                  )
                                : null,
                            onTap: () => context.push(
                              '/studies/questions/${question.id}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
