import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/group_providers.dart';
import '../data/group_models.dart';

class GroupEventsTab extends ConsumerWidget {
  const GroupEventsTab({
    super.key,
    required this.groupId,
    required this.detail,
  });

  final String groupId;
  final GroupDetail detail;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();
    var start = DateTime.now().add(const Duration(days: 1));
    var duration = 2;
    if (!context.mounted) return;

    final result = await showDialog<bool>(
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
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Titulo'),
                ),
                TextField(
                  controller: description,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Descricao (opcional)',
                  ),
                ),
                TextField(
                  controller: location,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Local (opcional)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: start,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              start = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                start.hour,
                                start.minute,
                              );
                            });
                          }
                        },
                        child: Text(
                          '${start.day.toString().padLeft(2, '0')}/'
                          '${start.month.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(start),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              start = DateTime(
                                start.year,
                                start.month,
                                start.day,
                                picked.hour,
                                picked.minute,
                              );
                            });
                          }
                        },
                        child: Text(
                          '${start.hour.toString().padLeft(2, '0')}:'
                          '${start.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<int>(
                  initialValue: duration,
                  decoration: const InputDecoration(labelText: 'Duracao'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 hora')),
                    DropdownMenuItem(value: 2, child: Text('2 horas')),
                    DropdownMenuItem(value: 4, child: Text('4 horas')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => duration = value ?? 2),
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
                if (title.text.trim().length < 3) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
    if (result != true) {
      title.dispose();
      description.dispose();
      location.dispose();
      return;
    }
    final eventTitle = title.text.trim();
    final eventDescription = description.text.trim();
    final eventLocation = location.text.trim();
    title.dispose();
    description.dispose();
    location.dispose();

    try {
      await ref
          .read(groupRepositoryProvider)
          .createEvent(
            groupId: groupId,
            title: eventTitle,
            description: eventDescription.isEmpty ? null : eventDescription,
            location: eventLocation.isEmpty ? null : eventLocation,
            startsAt: start,
            endsAt: start.add(Duration(hours: duration)),
          );
      ref.invalidate(groupEventsProvider(groupId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel criar o evento.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(groupEventsProvider(groupId));
    final rsvpsAsync = ref.watch(groupEventRsvpsProvider(groupId));
    final myId = Supabase.instance.client.auth.currentUser?.id;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Erro ao carregar eventos.')),
      data: (events) {
        final rsvps = rsvpsAsync.asData?.value ?? const [];
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (detail.canManageGroup)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _create(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo evento'),
                ),
              ),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text(
                  'Nenhum evento do grupo ainda.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
            for (final event in events)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (detail.canManageGroup)
                          IconButton(
                            tooltip: 'Apagar evento',
                            onPressed: () async {
                              await ref
                                  .read(groupRepositoryProvider)
                                  .deleteEvent(event.id);
                              ref.invalidate(groupEventsProvider(groupId));
                            },
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                      ],
                    ),
                    Text(
                      _dateRange(event.startsAt, event.endsAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.teal,
                      ),
                    ),
                    if (event.location != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.location!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    if (event.description != null) ...[
                      const SizedBox(height: 6),
                      Text(event.description!),
                    ],
                    if (myId != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _RsvpRow(
                        eventId: event.id,
                        groupId: groupId,
                        myId: myId,
                        rsvps: rsvps
                            .where((r) => r['event_id'] == event.id)
                            .toList(),
                        ref: ref,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

String _dateRange(DateTime start, DateTime end) {
  final s = start.toLocal();
  final e = end.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(s.day)}/${two(s.month)} ${two(s.hour)}:${two(s.minute)}'
      ' - ${two(e.day)}/${two(e.month)} ${two(e.hour)}:${two(e.minute)}';
}

class _RsvpRow extends StatelessWidget {
  const _RsvpRow({
    required this.eventId,
    required this.groupId,
    required this.myId,
    required this.rsvps,
    required this.ref,
  });

  final String eventId;
  final String groupId;
  final String myId;
  final List<Map<String, dynamic>> rsvps;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    String? myStatus;
    for (final row in rsvps) {
      if (row['user_id'] == myId) {
        myStatus = row['status'] as String?;
        break;
      }
    }
    final going = rsvps.where((r) => r['status'] == 'going').length;
    final interested = rsvps.where((r) => r['status'] == 'interested').length;

    Future<void> setStatus(String status) async {
      try {
        await ref.read(groupRepositoryProvider).setEventRsvp(eventId, status);
        ref.invalidate(groupEventRsvpsProvider(groupId));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nao foi possivel confirmar.')),
          );
        }
      }
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$going confirmados · $interested interessados'),
        ChoiceChip(
          label: const Text('Vou'),
          selected: myStatus == 'going',
          onSelected: (_) => setStatus('going'),
        ),
        ChoiceChip(
          label: const Text('Interesse'),
          selected: myStatus == 'interested',
          onSelected: (_) => setStatus('interested'),
        ),
        ChoiceChip(
          label: const Text('Nao vou'),
          selected: myStatus == 'declined',
          onSelected: (_) => setStatus('declined'),
        ),
      ],
    );
  }
}
