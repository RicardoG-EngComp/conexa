import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/conexa_top_bar.dart';
import '../data/campus_models.dart';
import '../data/campus_repository.dart';

class CampusMapScreen extends ConsumerStatefulWidget {
  const CampusMapScreen({super.key});

  @override
  ConsumerState<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends ConsumerState<CampusMapScreen> {
  static const _ufv = LatLng(-20.7645, -42.8695);
  String _category = 'Todos';
  bool _selecting = false;

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(campusPlacesProvider);

    return Scaffold(
      appBar: const ConexaTopBar(title: 'Mapa'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() => _selecting = !_selecting);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _selecting
                    ? 'Toque no mapa para marcar o novo local.'
                    : 'Seleção de local cancelada.',
              ),
            ),
          );
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(_selecting ? 'Toque no mapa' : 'Sugerir local'),
      ),
      body: placesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Erro ao carregar o mapa.')),
        data: (places) {
          final categories = [
            'Todos',
            ...places.map((place) => place.category).toSet().toList()..sort(),
          ];
          final filtered = _category == 'Todos'
              ? places
              : places.where((place) => place.category == _category).toList();

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: _ufv,
                  initialZoom: 15,
                  minZoom: 12,
                  maxZoom: 19,
                  onTap: (tapPosition, point) {
                    if (_selecting) _suggestPlace(point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ricardogengcomp.conexa',
                  ),
                  MarkerLayer(
                    markers: filtered
                        .map(
                          (place) => Marker(
                            point: LatLng(place.latitude, place.longitude),
                            width: 42,
                            height: 48,
                            child: GestureDetector(
                              onTap: () => _showPlace(place),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _iconFor(place.category),
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories
                        .map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: _category == category,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              if (places.isEmpty)
                Positioned(
                  bottom: 84,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Nenhum local aprovado ainda. Sugira um ponto para a moderação.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _iconFor(String category) {
    return switch (category) {
      'Comida' => Icons.restaurant_outlined,
      'Mercado' => Icons.local_grocery_store_outlined,
      'Farmácia' => Icons.local_pharmacy_outlined,
      'Hospital' => Icons.local_hospital_outlined,
      'Ponto turístico' => Icons.photo_camera_outlined,
      'Sala' => Icons.meeting_room_outlined,
      'Pavilhão' => Icons.apartment_outlined,
      _ => Icons.place_outlined,
    };
  }

  Future<void> _showPlace(CampusPlace place) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconFor(place.category), color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      place.name,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              Text(
                place.category,
                style: Theme.of(ctx).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              if (place.description != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(place.description!),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => _openRoute(place),
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Abrir rota'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRoute(CampusPlace place) async {
    final uri = Uri.parse(
      'https://www.openstreetmap.org/?mlat=${place.latitude}'
      '&mlon=${place.longitude}#map=19/${place.latitude}/${place.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _suggestPlace(LatLng point) async {
    setState(() => _selecting = false);
    final name = TextEditingController();
    final description = TextEditingController();
    var category = 'Outro';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Sugerir local'),
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
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
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
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    if (result == true && name.text.trim().isNotEmpty) {
      try {
        await ref
            .read(campusRepositoryProvider)
            .suggestPlace(
              name: name.text,
              category: category,
              latitude: point.latitude,
              longitude: point.longitude,
              description: description.text,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Local enviado para aprovação.')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível enviar o local.')),
          );
        }
      }
    }
    name.dispose();
    description.dispose();
  }
}
