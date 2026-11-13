import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/legal_urls.dart';
import '../../../core/errors/moderation_errors.dart';
import '../../../core/errors/moderation_ui.dart';
import '../../../core/media/media_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/study_providers.dart';

class StudyUploadScreen extends ConsumerStatefulWidget {
  const StudyUploadScreen({super.key, this.initialDisciplineId});

  final String? initialDisciplineId;

  @override
  ConsumerState<StudyUploadScreen> createState() => _StudyUploadScreenState();
}

class _StudyUploadScreenState extends ConsumerState<StudyUploadScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _link = TextEditingController();

  String _kind = 'pdf';
  String? _disciplineId;
  Uint8List? _bytes;
  String? _fileName;
  String? _contentType;
  int _size = 0;
  bool _rights = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _disciplineId = widget.initialDisciplineId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final isPdf = _kind == 'pdf';
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: isPdf ? ['pdf'] : ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      setState(() => _error = 'Não foi possível ler o arquivo.');
      return;
    }
    if (bytes.length > 10 * 1024 * 1024) {
      setState(() => _error = 'O arquivo deve ter no máximo 10 MB.');
      return;
    }
    final ext = (file.extension ?? '').toLowerCase();
    final contentType = switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    setState(() {
      _bytes = bytes;
      _fileName = file.name;
      _contentType = contentType;
      _size = bytes.length;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final disciplineId = _disciplineId;
    if (title.length < 3) {
      setState(() => _error = 'Dê um título com pelo menos 3 caracteres.');
      return;
    }
    if (disciplineId == null) {
      setState(() => _error = 'Escolha a disciplina.');
      return;
    }
    if (!_rights) {
      setState(
        () =>
            _error = 'Você precisa declarar que tem direitos sobre o material.',
      );
      return;
    }

    if (_kind == 'link') {
      final uri = Uri.tryParse(_link.text.trim());
      if (uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty) {
        setState(() => _error = 'Informe um link http(s) válido.');
        return;
      }
    } else if (_bytes == null) {
      setState(() => _error = 'Selecione o arquivo.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(studyRepositoryProvider);
      if (_kind == 'link') {
        await repo.createLinkMaterial(
          disciplineId: disciplineId,
          title: title,
          description: _description.text,
          url: _link.text.trim(),
        );
      } else {
        final path = await repo.uploadFile(
          bytes: _bytes!,
          contentType: _contentType!,
        );
        await repo.createFileMaterial(
          disciplineId: disciplineId,
          title: title,
          description: _description.text,
          storagePath: path,
          kind: _kind,
        );
      }
      ref.invalidate(pendingMaterialsProvider);
      ref.invalidate(materialsProvider(disciplineId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enviado para aprovação. Você verá quando for aprovado.',
          ),
        ),
      );
    } on MediaException catch (error) {
      if (mounted) {
        setState(() => _error = _mediaError(error.code));
      }
    } catch (error) {
      if (mounted) {
        if (needsGuidelinesAcceptance(error)) {
          await showGuidelinesConsentDialog(context);
        } else {
          setState(
            () => _error = friendlyModerationError(
              error,
              fallback: 'Não foi possível enviar o material.',
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mediaError(String code) {
    return switch (code) {
      'quota_estudo_arquivos' => 'Limite de 20 arquivos por mês atingido.',
      'quota_estudo_bytes' => 'Limite de 200 MB por mês atingido.',
      'arquivo_muito_grande' => 'O arquivo deve ter no máximo 10 MB.',
      'conteudo_nao_confere_com_tipo' => 'O formato do arquivo é inválido.',
      'nao_uploader' => 'Sua conta não pode enviar materiais.',
      'conta_inativa' => 'Sua conta não está ativa.',
      _ => 'Não foi possível enviar o material.',
    };
  }

  Future<void> _openCopyright() async {
    await launchUrl(
      Uri.parse(LegalUrls.copyright),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canUpload = ref.watch(canUploadProvider).asData?.value ?? false;
    final disciplinesAsync = ref.watch(disciplinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar material')),
      body: SafeArea(
        child: !canUpload
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Upload restrito aos convidados do piloto. '
                    'Fale com a administração para receber acesso.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              )
            : disciplinesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Center(child: Text('Erro ao carregar disciplinas.')),
                data: (disciplines) {
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Text(
                        'Materiais passam por aprovação antes de aparecer '
                        'para a comunidade.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_disciplineId),
                        initialValue: _disciplineId,
                        decoration: const InputDecoration(
                          labelText: 'Disciplina',
                        ),
                        items: disciplines
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(d.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _disciplineId = value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'pdf', label: Text('PDF')),
                          ButtonSegment(value: 'image', label: Text('Imagem')),
                          ButtonSegment(value: 'link', label: Text('Link')),
                        ],
                        selected: {_kind},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) => setState(() {
                          _kind = value.first;
                          _bytes = null;
                          _fileName = null;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _title,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          hintText: 'Ex.: Resumo de Cálculo I - limites',
                        ),
                      ),
                      TextField(
                        controller: _description,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Descrição (opcional)',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_kind == 'link')
                        TextField(
                          controller: _link,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Link',
                            hintText: 'https://...',
                          ),
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _pickFile,
                          icon: const Icon(Icons.attach_file),
                          label: Text(
                            _fileName == null
                                ? 'Selecionar arquivo'
                                : 'Trocar arquivo',
                          ),
                        ),
                        if (_fileName != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '$_fileName · ${(_size / 1024 / 1024).toStringAsFixed(1)} MB',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.md),
                      CheckboxListTile(
                        value: _rights,
                        onChanged: (value) =>
                            setState(() => _rights = value ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Declaro que sou autor ou tenho autorização para '
                          'compartilhar este material.',
                        ),
                        subtitle: const Text(
                          'Proibido enviar livros/PDFs pagos, provas vazadas, '
                          'gabaritos ou conteúdo ilegal.',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openCopyright,
                        icon: const Icon(Icons.policy_outlined),
                        label: const Text('Política de direitos autorais'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Enviar para aprovação'),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
