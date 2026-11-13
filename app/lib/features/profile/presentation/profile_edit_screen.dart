import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/media/image_processor.dart';
import '../../../core/media/media_image.dart';
import '../../../core/media/media_models.dart';
import '../../../core/media/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/uuid.dart';
import '../../verification/application/verification_providers.dart';
import '../application/profile_providers.dart';
import '../data/ufv_courses.dart';

const _favoriteCategories = {
  'music': 'Música',
  'series': 'Séries',
  'movie': 'Filmes',
  'anime': 'Animes',
};

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _picker = ImagePicker();

  final List<TextEditingController> _promptAnswers = List.generate(
    3,
    (_) => TextEditingController(),
  );
  final List<String?> _promptQuestions = List.filled(3, null);

  String? _course;
  String? _campus;
  String? _avatarPath;
  final List<String> _photos = [];
  final Set<String> _selectedFavoriteIds = {};

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    for (final c in _promptAnswers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(profileProvider.future);
      final user = Supabase.instance.client.auth.currentUser;
      final favoriteIds = user == null
          ? <String>{}
          : await ref.read(favoriteIdsProvider(user.id).future);
      final catalog = await ref.read(catalogProvider.future);

      if (!mounted) return;
      setState(() {
        _categoryByItemId.clear();
        for (final item in catalog) {
          _categoryByItemId[item['id'] as String] = item['category'] as String;
        }
        _name.text = (profile?['display_name'] as String?) ?? '';
        _bio.text = (profile?['bio'] as String?) ?? '';
        _course = profile?['course'] as String?;
        _campus = profile?['campus'] as String?;
        _avatarPath = profile?['avatar_url'] as String?;
        _photos
          ..clear()
          ..addAll(
            ((profile?['photos'] as List?) ?? []).map((e) => e as String),
          );

        final prompts = (profile?['prompts'] as List?) ?? [];
        for (var i = 0; i < 3; i++) {
          if (i < prompts.length && prompts[i] is Map) {
            final p = prompts[i] as Map;
            _promptQuestions[i] = p['question'] as String?;
            _promptAnswers[i].text = (p['answer'] as String?) ?? '';
          }
        }
        _selectedFavoriteIds
          ..clear()
          ..addAll(favoriteIds);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar o perfil.';
        });
      }
    }
  }

  Future<void> _pickAndUpload({required bool avatar}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (file == null) return;

    setState(() => _saving = true);
    try {
      final processed = await ImageProcessor.profileImage(
        await file.readAsBytes(),
        avatar: avatar,
      );
      final assetId = uuidV4();
      final kind = avatar ? 'avatar' : 'photo';
      final media = ref.read(mediaServiceProvider);

      final full = await media.uploadImage(
        bytes: processed.full,
        kind: kind,
        variant: 'full',
        contentType: 'image/webp',
        assetId: assetId,
        width: processed.width,
        height: processed.height,
      );

      try {
        await media.uploadImage(
          bytes: processed.thumb,
          kind: kind,
          variant: 'thumb',
          contentType: 'image/webp',
          assetId: assetId,
          width: processed.thumbWidth,
          height: processed.thumbHeight,
        );
      } catch (_) {
        // A foto cheia continua utilizavel; a lista cai no fallback.
      }

      if (!mounted) return;
      final path = full.key;
      if (avatar) {
        final old = _avatarPath;
        setState(() => _avatarPath = path);
        await ref.read(profileRepositoryProvider).updateProfile({
          'avatar_url': path,
        });
        ref.invalidate(profileProvider);
        if (old != null && old != path) {
          await media.deletePaths(scope: 'profile', paths: [old]);
        }
      } else {
        setState(() => _photos.add(path));
      }
      ref.invalidate(mediaVariantsProvider(path));
    } on MediaException catch (error) {
      if (mounted) setState(() => _error = _mediaError(error.code));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível enviar a foto.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removePhoto(String path) async {
    setState(() => _photos.remove(path));
    await ref.read(profileRepositoryProvider).updateProfile({
      'photos': _photos,
    });
    ref.invalidate(profileProvider);
    try {
      await ref
          .read(mediaServiceProvider)
          .deletePaths(scope: 'profile', paths: [path]);
    } on MediaException catch (error) {
      if (mounted) setState(() => _error = _mediaError(error.code));
    }
  }

  String _mediaError(String code) {
    return switch (code) {
      'quota_perfil' => 'Limite de fotos atingido.',
      'arquivo_muito_grande' => 'A imagem ficou grande demais.',
      'conteudo_nao_confere_com_tipo' => 'Formato de imagem inválido.',
      'conta_inativa' => 'Sua conta não está ativa.',
      _ => 'Não foi possível enviar a foto.',
    };
  }

  Future<void> _openFavorites(String category) async {
    final catalog = await ref.read(catalogProvider.future);
    final items = catalog
        .where((c) => c['category'] == category)
        .toList(growable: false);
    final idsInCategory = items.map((i) => i['id'] as String).toSet();
    final selected = _selectedFavoriteIds.where(idsInCategory.contains).toSet();

    if (!mounted) return;
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Favoritos: ${_favoriteCategories[category]}'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              children: [
                Text(
                  'Escolha até 5 (${selected.length}/5)',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: ListView(
                    children: items.map((item) {
                      final id = item['id'] as String;
                      return CheckboxListTile(
                        value: selected.contains(id),
                        title: Text(item['name'] as String),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              if (selected.length < 5) selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedFavoriteIds.removeWhere(idsInCategory.contains);
        _selectedFavoriteIds.addAll(result);
      });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final missing = <String>[];
    if (_avatarPath == null) missing.add('Foto de perfil');
    if (name.isEmpty) missing.add('Nome');
    if (_course == null) missing.add('Curso');
    if (_campus == null) missing.add('Campus');

    if (missing.isNotEmpty) {
      setState(() => _error = 'Falta completar: ${missing.join(', ')}.');
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Perfil incompleto'),
          content: Text(
            'Seu perfil não aparecerá na descoberta e você não poderá publicar '
            'nem enviar pedidos até completar:\n\n${missing.join(', ')}.\n\n'
            'Deseja salvar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar incompleto'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final prompts = <Map<String, String>>[];
      for (var i = 0; i < 3; i++) {
        final question = _promptQuestions[i];
        final answer = _promptAnswers[i].text.trim();
        if (question != null && answer.isNotEmpty) {
          prompts.add({'question': question, 'answer': answer});
        }
      }

      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile({
        'display_name': name,
        'course': _course,
        'campus': _campus,
        'bio': _bio.text.trim(),
        'prompts': prompts,
        'avatar_url': _avatarPath,
        'photos': _photos,
      });
      await repo.saveFavorites(_selectedFavoriteIds.toList());

      ref.invalidate(profileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil salvo.')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/feed');
      }
    } catch (_) {
      setState(() => _error = 'Não foi possível salvar o perfil.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Seu perfil')),
      body: SafeArea(
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _avatarPath == null,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Center(
                    child: Column(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 96,
                            height: 96,
                            child: _avatarPath == null
                                ? Container(
                                    color: AppColors.border,
                                    child: const Icon(Icons.person, size: 48),
                                  )
                                : MediaImage(
                                    path: _avatarPath!,
                                    width: 112,
                                    height: 112,
                                    useThumb: false,
                                  ),
                          ),
                        ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => _pickAndUpload(avatar: true),
                          child: const Text('Trocar foto de perfil'),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Fotos do perfil (até 6)',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final path in _photos)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: MediaImage(
                                path: path,
                                width: 96,
                                height: 96,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: _saving
                                    ? null
                                    : () => _removePhoto(path),
                              ),
                            ),
                          ],
                        ),
                      if (_photos.length < 6)
                        InkWell(
                          onTap: (_saving || _avatarPath == null)
                              ? null
                              : () => _pickAndUpload(avatar: false),
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _course,
                    decoration: const InputDecoration(labelText: 'Curso'),
                    items: ufvCourses
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _course = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _campus,
                    decoration: const InputDecoration(labelText: 'Campus'),
                    items: ufvCampuses
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _campus = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _bio,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: const InputDecoration(labelText: 'Bio'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Prompts', style: theme.textTheme.titleSmall),
                  for (var i = 0; i < 3; i++) ...[
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: _promptQuestions[i],
                      decoration: InputDecoration(
                        labelText: 'Pergunta ${i + 1}',
                      ),
                      items: profilePromptQuestions
                          .map(
                            (q) => DropdownMenuItem(value: q, child: Text(q)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _promptQuestions[i] = v),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _promptAnswers[i],
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Sua resposta',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text('Favoritos', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  for (final entry in _favoriteCategories.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                      subtitle: Text(
                        '${_selectedFavoriteIds.where((id) => _isInCategory(id, entry.key)).length}/5 selecionados',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving ? null : () => _openFavorites(entry.key),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar perfil'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _saving ? null : () => context.go('/feed'),
                    child: const Text(
                      'Continuar depois (completar em Ajustes)',
                    ),
                  ),
                ],
              ),
            ),
            if (_avatarPath == null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.72),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Primeiro, escolha sua foto de perfil',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Ela será a primeira foto do seu perfil. Depois você libera as demais.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _pickAndUpload(avatar: true),
                            icon: const Icon(Icons.add_a_photo),
                            label: const Text('Adicionar foto de perfil'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.teal,
                              minimumSize: const Size(280, 56),
                            ),
                          ),
                          if (_saving) ...[
                            const SizedBox(height: AppSpacing.md),
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isInCategory(String id, String category) {
    return _categoryByItemId[id] == category;
  }

  final Map<String, String> _categoryByItemId = {};
}
