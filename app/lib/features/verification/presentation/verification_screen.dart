import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zxing2/qrcode.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/verification_providers.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _picker = ImagePicker();
  XFile? _front;
  XFile? _back;
  XFile? _selfie;
  bool _loading = false;
  String? _error;

  Future<XFile?> _pick() {
    final source = kIsWeb ? ImageSource.gallery : ImageSource.camera;
    return _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
  }

  String? _decodeQr(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final pixels = decoded.getBytes(order: img.ChannelOrder.abgr);
      final int32 = Int32List.view(
        pixels.buffer,
        pixels.offsetInBytes,
        pixels.lengthInBytes ~/ 4,
      );
      final source = RGBLuminanceSource(decoded.width, decoded.height, int32);
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      return QRCodeReader().decode(bitmap).text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_front == null || _back == null || _selfie == null) {
      setState(() => _error = 'Capture as tres imagens para continuar.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('sem sessao');

      final repo = ref.read(verificationRepositoryProvider);
      final frontBytes = await _front!.readAsBytes();
      final backBytes = await _back!.readAsBytes();
      final selfieBytes = await _selfie!.readAsBytes();
      final qr = _decodeQr(backBytes);

      await repo.uploadImage(
        userId: user.id,
        name: 'front.jpg',
        bytes: frontBytes,
      );
      await repo.uploadImage(
        userId: user.id,
        name: 'back.jpg',
        bytes: backBytes,
      );
      await repo.uploadImage(
        userId: user.id,
        name: 'selfie.jpg',
        bytes: selfieBytes,
      );
      await repo.verifyCin(qr);

      ref.invalidate(profileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enviado para analise.')));
    } catch (e) {
      setState(() => _error = 'Nao foi possivel enviar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verificacao')),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Erro ao carregar status.')),
          data: (profile) {
            final status =
                (profile?['verification_status'] as String?) ?? 'unverified';
            if (status == 'pending') return _pendingView();
            if (status == 'verified') return _verifiedView();
            return _formView(rejected: status == 'rejected');
          },
        ),
      ),
    );
  }

  Widget _pendingView() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top, size: 48),
          const SizedBox(height: AppSpacing.lg),
          Text('Em analise', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Recebemos seus documentos. A revisao e feita manualmente e '
            'pode levar algum tempo.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () => ref.invalidate(profileProvider),
            child: const Text('Atualizar status'),
          ),
        ],
      ),
    );
  }

  Widget _verifiedView() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user, size: 48, color: AppColors.success),
          const SizedBox(height: AppSpacing.lg),
          Text('Identidade confirmada', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Sua idade foi confirmada. Agora vamos montar seu perfil.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => context.go('/profile-setup'),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Widget _formView({required bool rejected}) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Vamos confirmar sua idade',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Fotografe a frente do documento, o verso com QR Code e uma selfie. '
          'As imagens ficam privadas e sao apagadas apos a revisao.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        if (rejected) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'A verificacao anterior nao foi aprovada. Tente novamente.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.danger,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _CaptureTile(
          label: 'Frente do documento',
          file: _front,
          onTap: _loading
              ? null
              : () async {
                  final f = await _pick();
                  if (f != null) setState(() => _front = f);
                },
        ),
        const SizedBox(height: AppSpacing.md),
        _CaptureTile(
          label: 'Verso com QR Code',
          file: _back,
          onTap: _loading
              ? null
              : () async {
                  final f = await _pick();
                  if (f != null) setState(() => _back = f);
                },
        ),
        const SizedBox(height: AppSpacing.md),
        _CaptureTile(
          label: 'Selfie',
          file: _selfie,
          onTap: _loading
              ? null
              : () async {
                  final f = await _pick();
                  if (f != null) setState(() => _selfie = f);
                },
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
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar para analise'),
        ),
      ],
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    required this.label,
    required this.file,
    required this.onTap,
  });

  final String label;
  final XFile? file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captured = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: captured ? AppColors.teal : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              captured ? Icons.check_circle : Icons.add_a_photo_outlined,
              color: captured ? AppColors.teal : AppColors.muted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                captured ? '$label (capturado)' : label,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
