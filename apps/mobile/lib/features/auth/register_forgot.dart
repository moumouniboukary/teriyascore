import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/ts_widgets.dart';
import '../sync/sync_service.dart';
import 'app_lock.dart';
import 'auth_provider.dart';

/// Création d’un compte agent (téléphone + OTP + nom + PIN).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  int step = 0;
  final phoneCtrl = TextEditingController(text: '+226 ');
  final otpCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  String? otpToken;
  String? devCode;
  String? error;
  bool loading = false;

  @override
  void dispose() {
    phoneCtrl.dispose();
    otpCtrl.dispose();
    pinCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      loading = true;
      error = null;
      devCode = null;
    });
    try {
      final res = await ref
          .read(authProvider.notifier)
          .requestOtp(phoneCtrl.text.trim(), OtpPurpose.register);
      setState(() {
        devCode = res.devCode;
        step = 1;
      });
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final token = await ref.read(authProvider.notifier).verifyOtp(
            phoneCtrl.text.trim(),
            otpCtrl.text.trim(),
            OtpPurpose.register,
          );
      setState(() {
        otpToken = token;
        step = 2;
      });
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _register() async {
    if (otpToken == null) return;
    final t = ref.read(tsStringsProvider);
    final name = nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => error = t('nameRequired'));
      return;
    }
    if (pinCtrl.text.trim().length != 4) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ref.read(authProvider.notifier).register(
            phone: phoneCtrl.text.trim(),
            pin: pinCtrl.text.trim(),
            otpToken: otpToken!,
            displayName: name,
            language: ref.read(uxPrefsProvider).language,
          );
      await ref.read(appLockProvider.notifier).setupPin(pinCtrl.text.trim());
      unawaited(ref.read(syncServiceProvider).warmCaches());
      if (!mounted) return;
      context.go('/app');
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _handleBack() {
    if (step > 0) {
      setState(() => step -= 1);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tsStringsProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: tsBackButton(context, onPressed: _handleBack),
          title: Text(t('register')),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                t('newAccount'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                t('noAccountHint'),
                style: TextStyle(color: TsTokens.textMute),
              ),
              const SizedBox(height: 20),
              if (step == 0) ...[
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: t('phone')),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: TsTokens.danger)),
                ],
                const SizedBox(height: 16),
                TsPrimaryButton(
                  label: loading ? 'Envoi…' : t('receiveCode'),
                  loading: loading,
                  onPressed: _sendOtp,
                ),
              ] else if (step == 1) ...[
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: t('smsCode')),
                ),
                if (devCode != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: TsTokens.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TsTokens.line),
                    ),
                    child: Text(
                      'Mode test · votre code est $devCode',
                      style: const TextStyle(color: TsTokens.sand),
                    ),
                  ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: TsTokens.danger)),
                const SizedBox(height: 16),
                TsPrimaryButton(
                  label: t('continue'),
                  loading: loading,
                  onPressed: otpCtrl.text.length == 4 ? _verify : null,
                ),
              ] else ...[
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: t('displayName'),
                    hintText: t('displayNameHint'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: t('pinHint')),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: TsTokens.danger)),
                const SizedBox(height: 16),
                TsPrimaryButton(
                  label: t('createAccount'),
                  loading: loading,
                  onPressed: pinCtrl.text.length == 4 ? _register : null,
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(t('haveAccount')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  int step = 0;
  final phoneCtrl = TextEditingController(text: '+226 ');
  final otpCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  String? otpToken;
  String? devCode;
  String? info;
  String? error;
  bool loading = false;
  bool done = false;

  @override
  void dispose() {
    phoneCtrl.dispose();
    otpCtrl.dispose();
    pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/auth/forgot-password',
            data: {'phone': phoneCtrl.text.trim()},
            parse: (d) => Map<String, dynamic>.from(d as Map),
          );
      setState(() {
        info =
            data['message'] as String? ??
            'Si le compte existe, un code a été envoyé.';
        devCode = data['devCode'] as String?;
        step = 1;
      });
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final token = await ref
          .read(authProvider.notifier)
          .verifyOtp(
            phoneCtrl.text.trim(),
            otpCtrl.text.trim(),
            OtpPurpose.reset,
          );
      setState(() {
        otpToken = token;
        step = 2;
      });
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _reset() async {
    if (otpToken == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/auth/reset-password',
            data: {
              'phone': phoneCtrl.text.trim(),
              'otpToken': otpToken,
              'newPin': pinCtrl.text.trim(),
            },
          );
      setState(() => done = true);
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      setState(() => loading = false);
    }
  }

  void _handleBack() {
    if (done) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/login');
      }
      return;
    }
    if (step > 0) {
      setState(() => step -= 1);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: tsBackButton(context, onPressed: _handleBack),
          title: const Text('Code PIN oublié'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (done) ...[
                Text(
                  'Code PIN mis à jour',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Reconnectez-vous avec votre nouveau code.',
                  style: TextStyle(color: TsTokens.textMute),
                ),
                const SizedBox(height: 16),
                TsPrimaryButton(
                  label: 'Se connecter',
                  onPressed: () => context.go('/login'),
                ),
              ] else if (step == 0) ...[
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                if (error != null)
                  Text(error!, style: TextStyle(color: TsTokens.danger)),
                const SizedBox(height: 16),
                TsPrimaryButton(
                  label: 'Recevoir un code',
                  loading: loading,
                  onPressed: _send,
                ),
              ] else if (step == 1) ...[
                if (info != null)
                  Text(info!, style: TextStyle(color: TsTokens.textMute)),
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Code SMS'),
                ),
                if (devCode != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: TsTokens.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TsTokens.line),
                    ),
                    child: Text(
                      'Mode test · votre code est $devCode',
                      style: const TextStyle(color: TsTokens.sand),
                    ),
                  ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: TsTokens.danger)),
                const SizedBox(height: 16),
                TsPrimaryButton(
                  label: 'Continuer',
                  loading: loading,
                  onPressed: otpCtrl.text.length == 4 ? _verify : null,
                ),
              ] else ...[
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Nouveau code PIN',
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: TsTokens.danger)),
                const SizedBox(height: 16),
                TsPrimaryButton(
                  label: 'Enregistrer',
                  loading: loading,
                  onPressed: pinCtrl.text.length == 4 ? _reset : null,
                ),
              ],
              TextButton(onPressed: _handleBack, child: const Text('Retour')),
            ],
          ),
        ),
      ),
    );
  }
}
