import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/ts_widgets.dart';
import '../sync/sync_service.dart';
import 'app_lock.dart';
import 'auth_provider.dart';

/// Page d'accueil publique (avant connexion).
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final t = ref.watch(tsStringsProvider);
    if (!auth.ready) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: TsTokens.brand)),
      );
    }

    return Scaffold(
      backgroundColor: TsTokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    t('appName'),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                      color: TsTokens.text,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: TsTokens.brand.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      t('splashBadge'),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TsTokens.brandSoft,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 148,
                      child: CustomPaint(
                        painter: _ScoreGaugePainter(
                          progress: 0.72,
                          track: TsTokens.line,
                          fill: TsTokens.brand,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '700',
                                  style: GoogleFonts.outfit(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                    color: TsTokens.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t('splashScale'),
                                  style: TextStyle(
                                    color: TsTokens.textMute,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      t('splashHeadline'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.4,
                        color: TsTokens.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t('splashSubtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TsTokens.textMute,
                        height: 1.45,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
              TsPrimaryButton(
                label: auth.isAuthenticated ? t('continue') : t('start'),
                onPressed: () {
                  if (!auth.isAuthenticated) {
                    context.push('/register');
                  } else {
                    context.go('/app');
                  }
                },
              ),
              if (!auth.isAuthenticated) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: Text(t('login')),
                    ),
                    Text(
                      '·',
                      style: TextStyle(
                        color: TsTokens.textMute,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).enterLocalDemo();
                        if (context.mounted) context.go('/app');
                      },
                      child: Text(t('tryWithoutAccount')),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreGaugePainter extends CustomPainter {
  _ScoreGaugePainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 12.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2 + 8,
      size.width - stroke,
      size.height * 1.35,
    );
    const start = 3.1416 * 1.08;
    const sweep = 3.1416 * 0.84;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, start, sweep, false, trackPaint);
    canvas.drawArc(rect, start, sweep * progress.clamp(0.0, 1.0), false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  int step = 0;
  final phoneCtrl = TextEditingController(text: '+226 ');
  final otpCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  String? otpToken;
  String? devCode;
  String? error;
  bool loading = false;
  bool hasLocalSession = false;

  @override
  void initState() {
    super.initState();
    _checkLocalSession();
  }

  Future<void> _checkLocalSession() async {
    final session = ref.read(sessionStorageProvider);
    final token = await session.getAccessToken();
    final user = await session.getUser();
    if (!mounted) return;
    setState(() => hasLocalSession = token != null && user != null);
  }

  Future<void> _continueOffline() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final ok = await ref.read(authProvider.notifier).resumeLocalSession();
      if (!ok) {
        setState(() {
          hasLocalSession = false;
          error = ref.read(tsStringsProvider)('loginNeedsNetwork');
        });
        return;
      }
      if (!mounted) return;
      context.go('/app');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    phoneCtrl.dispose();
    otpCtrl.dispose();
    pinCtrl.dispose();
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
          .requestOtp(phoneCtrl.text.trim(), OtpPurpose.login);
      setState(() {
        devCode = res.devCode;
        step = 1;
      });
      } on ApiException catch (e) {
      setState(() => error = _loginError(e));
    } finally {
      setState(() => loading = false);
    }
  }

  String _loginError(ApiException e) {
    final code = e.body is Map ? e.body['error']?.toString() : null;
    if (code == 'account_missing' ||
        (e.status == 404 && (e.message.contains('inexistant') || e.message.contains('Compte')))) {
      return 'Aucun compte agent pour ce numéro. Contactez DigiCoop.';
    }
    if (e.isOffline) {
      return e.message.isNotEmpty && e.message != 'Hors ligne'
          ? e.message
          : ref.read(tsStringsProvider)('loginNeedsNetwork');
    }
    return e.message;
  }

  Future<void> _verifyOtp() async {
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
            OtpPurpose.login,
          );
      setState(() {
        otpToken = token;
        step = 2;
      });
      } on ApiException catch (e) {
      setState(() => error = _loginError(e));
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _login() async {
    if (otpToken == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .login(
            phone: phoneCtrl.text.trim(),
            pin: pinCtrl.text.trim(),
            otpToken: otpToken!,
          );
      await ref.read(appLockProvider.notifier).setupPin(pinCtrl.text.trim());
      // Précharge le cache pour un usage hors ligne immédiat.
      unawaited(ref.read(syncServiceProvider).warmCaches());
      if (!mounted) return;
      context.go('/app');
    } on ApiException catch (e) {
      setState(() => error = _loginError(e));
    } finally {
      setState(() => loading = false);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: tsBackButton(context, onPressed: _handleBack),
          title: const Text('Connexion'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (step == 0) ...[
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: TsTokens.danger)),
                ],
                const SizedBox(height: 16),
                TsPrimaryButton(
                  label: loading ? 'Envoi…' : 'Recevoir le code',
                  loading: loading,
                  onPressed: _sendOtp,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: Text(ref.watch(tsStringsProvider)('createAgentAccount')),
                ),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () async {
                            await ref
                                .read(authProvider.notifier)
                                .enterLocalDemo();
                            if (!context.mounted) return;
                            context.go('/app');
                          },
                    child: Text(ref.watch(tsStringsProvider)('tryWithoutAccount')),
                  ),
                if (hasLocalSession) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: loading ? null : _continueOffline,
                    child: Text(ref.watch(tsStringsProvider)('continueOffline')),
                  ),
                ],
              ] else if (step == 1) ...[
                Text(
                  'Code SMS',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
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
                  onPressed: otpCtrl.text.length == 4 ? _verifyOtp : null,
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setState(() => loading = true);
                          try {
                            final res = await ref
                                .read(authProvider.notifier)
                                .requestOtp(
                                  phoneCtrl.text.trim(),
                                  OtpPurpose.login,
                                );
                            setState(() {
                              devCode = res.devCode;
                              otpCtrl.clear();
                            });
                          } on ApiException catch (e) {
                            setState(() => error = e.message);
                          } finally {
                            setState(() => loading = false);
                          }
                        },
                  child: const Text('Renvoyer le code'),
                ),
              ] else ...[
                Text(
                  'Votre code PIN',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Code PIN'),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: TsTokens.danger)),
                const SizedBox(height: 16),
                TsPrimaryButton(
                  label: 'Se connecter',
                  loading: loading,
                  onPressed: pinCtrl.text.length == 4 ? _login : null,
                ),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Code PIN oublié ?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
