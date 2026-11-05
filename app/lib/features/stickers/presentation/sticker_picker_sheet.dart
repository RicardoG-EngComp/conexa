import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/sticker_providers.dart';
import '../data/sticker_models.dart';
import 'create_sticker_pack_screen.dart';

class StickerPickerSheet extends ConsumerWidget {
  const StickerPickerSheet({super.key, required this.conversationId});

  final String conversationId;

  Future<void> _sendSticker(
    BuildContext context,
    WidgetRef ref,
    StickerItem item,
  ) async {
    try {
      await ref.read(stickerRepositoryProvider).sendSticker(
            conversationId: conversationId,
            stickerPath: item.imagePath,
          );
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel enviar a figurinha.')),
        );
      }
    }
  }

  Future<void> _sendGif(
    BuildContext context,
    WidgetRef ref,
    GiphyItem item,
  ) async {
    try {
      await ref.read(stickerRepositoryProvider).sendGif(
            conversationId: conversationId,
            gifUrl: item.originalUrl,
          );
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel enviar o GIF.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Globais'),
                Tab(text: 'GIPHY'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _PackBrowser(
                    isPublic: true,
                    onSticker: (item) => _sendSticker(context, ref, item),
                  ),
                  _GiphyTab(
                    onGif: (item) => _sendGif(context, ref, item),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackBrowser extends ConsumerStatefulWidget {
  const _PackBrowser({required this.isPublic, required this.onSticker});

  final bool isPublic;
  final ValueChanged<StickerItem> onSticker;

  @override
  ConsumerState<_PackBrowser> createState() => _PackBrowserState();
}

class _PackBrowserState extends ConsumerState<_PackBrowser> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final packsAsync = ref.watch(stickerPacksProvider);
    final repo = ref.read(stickerRepositoryProvider);

    return packsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Erro ao carregar pacotes.')),
      data: (packs) {
        final filtered =
            packs.where((p) => p.isPublic == widget.isPublic).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.isPublic
                    ? 'Nenhum pacote global ainda.'
                    : 'Voce ainda nao criou pacotes.'),
                if (!widget.isPublic) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CreateStickerPackScreen(),
                        ),
                      );
                      ref.invalidate(stickerPacksProvider);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Criar pacote'),
                  ),
                ],
              ],
            ),
          );
        }

        final selected = filtered.firstWhere(
          (p) => p.id == _selected,
          orElse: () => filtered.first,
        );
        final stickersAsync = ref.watch(stickersProvider(selected.id));

        return Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: filtered.length + (widget.isPublic ? 0 : 1),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (!widget.isPublic && index == filtered.length) {
                    return ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Novo'),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CreateStickerPackScreen(),
                          ),
                        );
                        ref.invalidate(stickerPacksProvider);
                      },
                    );
                  }
                  final pack = filtered[index];
                  return ChoiceChip(
                    label: Text(pack.name),
                    selected: pack.id == selected.id,
                    onSelected: (_) => setState(() => _selected = pack.id),
                  );
                },
              ),
            ),
            Expanded(
              child: stickersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Center(child: Text('Erro ao carregar figurinhas.')),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('Pacote vazio.'));
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        onTap: () => widget.onSticker(item),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.network(
                            repo.publicUrl(item.imagePath),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GiphyTab extends ConsumerStatefulWidget {
  const _GiphyTab({required this.onGif});

  final ValueChanged<GiphyItem> onGif;

  @override
  ConsumerState<_GiphyTab> createState() => _GiphyTabState();
}

class _GiphyTabState extends ConsumerState<_GiphyTab> {
  final _controller = TextEditingController();
  String _type = 'gifs';
  List<GiphyItem> _items = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref
          .read(stickerRepositoryProvider)
          .searchGiphy(query: query, type: _type);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = 'Nao foi possivel buscar no GIPHY.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _load,
                  decoration: const InputDecoration(
                    hintText: 'Buscar GIFs e figurinhas',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'gifs', label: Text('GIF')),
                  ButtonSegment(value: 'stickers', label: Text('Fig.')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (value) {
                  setState(() => _type = value.first);
                  _load(_controller.text.trim());
                },
              ),
            ],
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(child: Text(_error!)))
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return InkWell(
                  onTap: () => widget.onGif(item),
                  child: Image.network(
                    item.previewUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            'Powered by GIPHY',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
