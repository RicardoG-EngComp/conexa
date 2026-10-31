import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_providers.dart';
import 'validators.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  DateTime? _birthDate;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      setState(() => _error = 'Informe sua data de nascimento.');
      return;
    }
    if (ageFromDate(_birthDate!) < 18) {
      setState(() => _error = 'O app e exclusivo para maiores de 18 anos.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref
          .read(authRepositoryProvider)
          .signUp(
            email: _email.text.trim(),
            password: _password.text,
            birthDate: _birthDate!,
          );

      if (!mounted) return;
      if (response.session == null) {
        context.go('/check-email');
      } else {
        context.go('/consent');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(
        () => _error = 'Nao foi possivel criar a conta. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta UFV')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Seus dados de acesso', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Use seu e-mail institucional @alunos.ufv.br.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: validateUfvEmail,
                decoration: const InputDecoration(
                  labelText: 'E-mail institucional',
                  hintText: 'nome@alunos.ufv.br',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                obscureText: true,
                validator: validatePassword,
                decoration: const InputDecoration(labelText: 'Senha'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                validator: (v) =>
                    validatePasswordConfirmation(v, _password.text),
                decoration: const InputDecoration(labelText: 'Confirmar senha'),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _loading ? null : _pickBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de nascimento',
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _birthDate == null
                            ? 'Selecionar data'
                            : _formatDate(_birthDate!),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 18),
                    ],
                  ),
                ),
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
                    : const Text('Criar conta'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _loading ? null : () => context.go('/sign-in'),
                child: const Text('Ja tenho conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
