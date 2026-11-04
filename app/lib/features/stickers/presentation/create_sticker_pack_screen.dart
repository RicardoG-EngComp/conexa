import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/sticker_providers.dart';

class CreateStickerPackScreen extends ConsumerStatefulWidget {
  const CreateStickerPackScreen({super.key});

  @override
  ConsumerState<CreateStickerPackScreen> createState() =>
      _CreateStickerPackScreenState();
}

class _CreateStickerPackScreenState
    extends ConsumerState<CreateStickerPackScreen> {
  final _name = TextEditingController();
  final _picker = ImagePicker();
  final List<Uint8List> _images = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await _picker.pickMultiImage(imageQuality: 90);
    if (files.isEmpty) return;
    final encoded = <Uint8List>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;
      var resized = decoded;
      if (decoded.width > 512 || decoded.height > 512) {
        resized = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 512 : null,
          height: decoded.height > decoded.width ? 512 : null,
        );
      }
      encoded.add(Uint8List.fromList(img.encodePng(resized)));
    }
    if (!mounted) return;
    setState(() {
      _images.addAll(encoded);
      _error = null;
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'De um nome ao pacote.');
      return;
    }
    if (_images.isEmpty) {
      setState(() => _error = 'Adicione ao menos uma imagem.');
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(stickerRepositoryProvider);
      final packId = await repo.createPack(name);
      for (final bytes in _images) {
        await repo.uploadSticker(
          packId: packId,
          userId: user.id,
          bytes: bytes,
        );
      }
      ref.invalidate(stickerPacksProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Falha ao criar o pacote. Verifique o limite de 50 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar pacote')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextField(
              controller: _name,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Nome do pacote',
                hintText: 'Ex.: Meus memes',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Adicionar imagens'),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '${_images.length} figurinha(s)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final bytes in _images)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.memory(
                        bytes,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Criar pacote'),
            ),
          ],
        ),
      ),
    );
  }
}
