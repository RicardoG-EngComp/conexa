import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reports/application/report_providers.dart';
import '../../reports/presentation/report_dialog.dart';

const _categories = [
  'intolerancia_discriminacao',
  'violencia_ameaca',
  'conteudo_sexual_explicito',
  'assedio',
];

class AdminModerationTermsScreen extends ConsumerStatefulWidget {
  const AdminModerationTermsScreen({super.key});

  @override
  ConsumerState<AdminModerationTermsScreen> createState() =>
      _AdminModerationTermsScreenState();
}

class _AdminModerationTermsScreenState
    extends ConsumerState<AdminModerationTermsScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _terms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _client
          .from('moderation_terms')
          .select('id, term, category, active')
          .order('category')
          .order('term');
      if (!mounted) return;
      setState(() => _terms = (rows as List).cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro ao carregar termos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final term = TextEditingController();
    String category = _categories.first;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Novo termo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: term,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Termo'),
              ),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: _categories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(reportCategories[item] ?? item),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => category = value ?? _categories.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (term.text.trim().length < 2) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
    final value = term.text.trim();
    term.dispose();
    if (result != true) return;

    try {
      await _client.from('moderation_terms').insert({
        'term': value,
        'normalized_term': value.toLowerCase(),
        'category': category,
        'active': true,
      });
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel adicionar o termo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider).asData?.value ?? false;
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Termos de moderacao')),
        body: const Center(child: Text('Acesso restrito.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos de moderacao'),
        actions: [
          IconButton(
            tooltip: 'Novo termo',
            onPressed: _add,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _terms.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final item = _terms[index];
                final active = item['active'] == true;
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['term'] as String),
                  subtitle: Text(
                    reportCategories[item['category']] ??
                        (item['category'] as String),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  value: active,
                  onChanged: (value) async {
                    await _client
                        .from('moderation_terms')
                        .update({'active': value})
                        .eq('id', item['id']);
                    _load();
                  },
                  secondary: IconButton(
                    tooltip: 'Apagar',
                    onPressed: () async {
                      await _client
                          .from('moderation_terms')
                          .delete()
                          .eq('id', item['id']);
                      _load();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                );
              },
            ),
    );
  }
}
