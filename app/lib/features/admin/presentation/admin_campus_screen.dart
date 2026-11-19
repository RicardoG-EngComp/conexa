import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class AdminCampusScreen extends ConsumerStatefulWidget {
  const AdminCampusScreen({super.key});

  @override
  ConsumerState<AdminCampusScreen> createState() => _AdminCampusScreenState();
}

class _AdminCampusScreenState extends ConsumerState<AdminCampusScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final places = await _client
        .from('campus_places')
        .select()
        .order('created_at', ascending: false);
    final events = await _client
        .from('campus_events')
        .select()
        .order('starts_at', ascending: false);
    if (!mounted) return;
    setState(() {
      _places = (places as List).cast<Map<String, dynamic>>();
      _events = (events as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _setStatus(String table, String id, String status) async {
    await _client.from(table).update({'status': status}).eq('id', id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Campus'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Locais'),
              Tab(text: 'Eventos'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _PlacesTab(
                    items: _places,
                    onStatus: (id, status) =>
                        _setStatus('campus_places', id, status),
                    onAdd: _addPlace,
                  ),
                  _EventsTab(
                    items: _events,
                    onStatus: (id, status) =>
                        _setStatus('campus_events', id, status),
                    onAdd: _addEvent,
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final index = DefaultTabController.of(context).index;
            if (index == 0) {
              _addPlace();
            } else {
              _addEvent();
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _addPlace() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final latitude = TextEditingController(text: '-20.7645');
    final longitude = TextEditingController(text: '-42.8695');
    var category = 'Outro';
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Novo local'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items:
                      const [
                            'Pavilhão',
                            'Sala',
                            'Comida',
                            'Mercado',
                            'Farmácia',
                            'Hospital',
                            'Ponto turístico',
                            'Outro',
                          ]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setDialogState(() => category = value ?? 'Outro'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: latitude,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: longitude,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrição'),
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (save == true && name.text.trim().isNotEmpty) {
      final lat = double.tryParse(latitude.text.replaceAll(',', '.'));
      final lng = double.tryParse(longitude.text.replaceAll(',', '.'));
      if (lat != null && lng != null) {
        await _client.from('campus_places').insert({
          'name': name.text.trim(),
          'category': category,
          'latitude': lat,
          'longitude': lng,
          'description': description.text.trim(),
          'status': 'approved',
          'created_by': _client.auth.currentUser?.id,
          'approved_by': _client.auth.currentUser?.id,
        });
        await _load();
      }
    }
    name.dispose();
    description.dispose();
    latitude.dispose();
    longitude.dispose();
  }

  Future<void> _addEvent() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();
    final ticket = TextEditingController();
    var startsAt = DateTime.now().add(const Duration(days: 1));
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Novo evento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: location,
                  decoration: const InputDecoration(labelText: 'Local'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: ticket,
                  decoration: const InputDecoration(
                    labelText: 'Link de ingressos (opcional)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startsAt,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      setDialogState(() => startsAt = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    '${startsAt.day.toString().padLeft(2, '0')}/'
                    '${startsAt.month.toString().padLeft(2, '0')}/'
                    '${startsAt.year}',
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (save == true && title.text.trim().isNotEmpty) {
      await _client.from('campus_events').insert({
        'title': title.text.trim(),
        'description': description.text.trim(),
        'starts_at': startsAt.toUtc().toIso8601String(),
        'location': location.text.trim(),
        'ticket_url': ticket.text.trim().isEmpty ? null : ticket.text.trim(),
        'status': 'approved',
        'created_by': _client.auth.currentUser?.id,
        'approved_by': _client.auth.currentUser?.id,
      });
      await _load();
    }
    title.dispose();
    description.dispose();
    location.dispose();
    ticket.dispose();
  }
}

class _PlacesTab extends StatelessWidget {
  const _PlacesTab({
    required this.items,
    required this.onStatus,
    required this.onAdd,
  });

  final List<Map<String, dynamic>> items;
  final void Function(String id, String status) onStatus;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _ModerationList(
      items: items,
      title: (item) => (item['name'] as String?) ?? 'Local',
      subtitle: (item) => (item['category'] as String?) ?? '',
      onStatus: onStatus,
      empty: 'Nenhum local cadastrado.',
    );
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab({
    required this.items,
    required this.onStatus,
    required this.onAdd,
  });

  final List<Map<String, dynamic>> items;
  final void Function(String id, String status) onStatus;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _ModerationList(
      items: items,
      title: (item) => (item['title'] as String?) ?? 'Evento',
      subtitle: (item) => (item['location'] as String?) ?? '',
      onStatus: onStatus,
      empty: 'Nenhum evento cadastrado.',
    );
  }
}

class _ModerationList extends StatelessWidget {
  const _ModerationList({
    required this.items,
    required this.title,
    required this.subtitle,
    required this.onStatus,
    required this.empty,
  });

  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) title;
  final String Function(Map<String, dynamic>) subtitle;
  final void Function(String id, String status) onStatus;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(empty));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final item = items[index];
        final status = (item['status'] as String?) ?? 'pending';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title(item)),
          subtitle: Text('$status · ${subtitle(item)}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Aprovar',
                onPressed: status == 'approved'
                    ? null
                    : () => onStatus(item['id'] as String, 'approved'),
                icon: const Icon(Icons.check_circle_outline),
                color: AppColors.success,
              ),
              IconButton(
                tooltip: 'Rejeitar',
                onPressed: status == 'rejected'
                    ? null
                    : () => onStatus(item['id'] as String, 'rejected'),
                icon: const Icon(Icons.cancel_outlined),
                color: AppColors.danger,
              ),
            ],
          ),
        );
      },
    );
  }
}
