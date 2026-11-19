import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/conexa_top_bar.dart';
import '../../campus/data/campus_models.dart';
import '../../campus/data/campus_repository.dart';
import '../data/search_models.dart';
import '../data/search_repository.dart';

class StudySearchScreen extends ConsumerStatefulWidget {
  const StudySearchScreen({super.key});

  @override
  ConsumerState<StudySearchScreen> createState() => _StudySearchScreenState();
}

class _StudySearchScreenState extends ConsumerState<StudySearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _filter = 'all';
  StudySearchResults _results = const StudySearchResults();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value);
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(studySearchRepositoryProvider)
          .search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível buscar agora.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = ref.watch(campusEventsProvider).asData?.value ?? const [];

    return Scaffold(
      appBar: const ConexaTopBar(showLogo: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _search(_query.text),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              TextField(
                controller: _query,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                decoration: const InputDecoration(
                  hintText: 'Busque disciplina, tema, professor ou material',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (events.isNotEmpty) ...[
                _EventBillboard(events: events),
                const SizedBox(height: AppSpacing.md),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tudo',
                      selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    _FilterChip(
                      label: 'Materiais',
                      selected: _filter == 'materials',
                      onTap: () => setState(() => _filter = 'materials'),
                    ),
                    _FilterChip(
                      label: 'Disciplinas',
                      selected: _filter == 'disciplines',
                      onTap: () => setState(() => _filter = 'disciplines'),
                    ),
                    _FilterChip(
                      label: 'Professores',
                      selected: _filter == 'professors',
                      onTap: () => setState(() => _filter = 'professors'),
                    ),
                    _FilterChip(
                      label: 'Q&A',
                      selected: _filter == 'questions',
                      onTap: () => setState(() => _filter = 'questions'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _EmptyState(message: _error!)
              else if (_results.isEmpty)
                _EmptyState(
                  message: _query.text.trim().isEmpty
                      ? 'Busque por um tema, disciplina ou professor.'
                      : 'Nenhum resultado encontrado.',
                )
              else ...[
                if (_filter == 'all' || _filter == 'materials')
                  _MaterialsSection(results: _results.materials),
                if (_filter == 'all' || _filter == 'disciplines')
                  _DisciplinesSection(results: _results.disciplines),
                if (_filter == 'all' || _filter == 'professors')
                  _ProfessorsSection(
                    results: _results.professors,
                    onSelect: (name) {
                      _query.text = name;
                      _search(name);
                    },
                  ),
                if (_filter == 'all' || _filter == 'questions')
                  _QuestionsSection(results: _results.questions),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (events.isEmpty)
                Text(
                  'Eventos do campus aparecerão aqui quando forem aprovados.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventBillboard extends StatelessWidget {
  const _EventBillboard({required this.events});

  final List<CampusEvent> events;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: PageView.builder(
        itemCount: events.length > 6 ? 6 : events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _showEvent(context, event),
                child: Ink(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF09318D), Color(0xFF0693C6)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.campaign_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                      const Spacer(),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          _date(event.startsAt),
                          if (event.location != null) event.location!,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';
  }
}

Future<void> _showEvent(BuildContext context, CampusEvent event) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(event.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_eventDate(event.startsAt)),
          if (event.location != null) ...[
            const SizedBox(height: 4),
            Text(event.location!),
          ],
          if (event.description != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(event.description!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Fechar'),
        ),
        if (event.ticketUrl != null)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ingressos'),
          ),
      ],
    ),
  );
  if (open == true && event.ticketUrl != null) {
    final uri = Uri.tryParse(event.ticketUrl!);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

String _eventDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')} às '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _MaterialsSection extends StatelessWidget {
  const _MaterialsSection({required this.results});

  final List<StudyMaterialResult> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Materiais',
      children: results
          .map(
            (item) => _ResultTile(
              icon: Icons.menu_book_outlined,
              title: item.title,
              subtitle: [
                item.disciplineName,
                if (item.professorName != null) item.professorName!,
              ].join(' · '),
              onTap: () => context.push('/studies/material/${item.id}'),
            ),
          )
          .toList(),
    );
  }
}

class _DisciplinesSection extends StatelessWidget {
  const _DisciplinesSection({required this.results});

  final List<StudyDisciplineResult> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Disciplinas',
      children: results
          .map(
            (item) => _ResultTile(
              icon: Icons.school_outlined,
              title: item.name,
              subtitle: [
                if (item.course != null) item.course!,
                if (item.professorName != null) item.professorName!,
              ].join(' · '),
              onTap: () => context.push('/studies/discipline/${item.id}'),
            ),
          )
          .toList(),
    );
  }
}

class _ProfessorsSection extends StatelessWidget {
  const _ProfessorsSection({required this.results, required this.onSelect});

  final List<StudyProfessorResult> results;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Professores',
      children: results
          .map(
            (item) => _ResultTile(
              icon: Icons.person_search_outlined,
              title: item.name,
              subtitle: item.disciplines.isEmpty
                  ? 'Professor'
                  : item.disciplines.take(3).join(' · '),
              onTap: () => onSelect(item.name),
            ),
          )
          .toList(),
    );
  }
}

class _QuestionsSection extends StatelessWidget {
  const _QuestionsSection({required this.results});

  final List<StudyQuestionResult> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Perguntas',
      children: results
          .map(
            (item) => _ResultTile(
              icon: Icons.forum_outlined,
              title: item.title,
              subtitle: item.disciplineName,
              onTap: () => context.push('/studies/questions/${item.id}'),
            ),
          )
          .toList(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.teal),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.trim().isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
