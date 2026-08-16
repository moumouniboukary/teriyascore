import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/offline/local_cache.dart';
import 'core/offline/queue.dart';
import 'core/theme/tokens.dart';
import 'core/l10n/locale_provider.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/brand_splash.dart';
import 'features/sync/sync_service.dart';
import 'router.dart';

/// Mappe la langue interface (fr | mr) vers une [Locale] Material supportée.
/// Le mooré n'a pas de délégué Material officiel : rendu système en français,
/// libellés via `TsStrings` / [tsStringsProvider].
Locale _materialLocaleFor(String lang) {
  switch (lang) {
    case 'mr':
    case 'fr':
    default:
      return const Locale('fr', 'FR');
  }
}

ThemeMode _themeModeFor(String themePref) {
  switch (themePref) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final queue = OfflineQueue();
  await queue.init();
  final cache = LocalCache();
  await cache.init();
  await NotificationService.instance.init();

  runApp(
    ProviderScope(
      overrides: [
        offlineQueueProvider.overrideWithValue(queue),
        localCacheProvider.overrideWithValue(cache),
      ],
      child: const TeriyaScoreApp(),
    ),
  );
}

class TeriyaScoreApp extends ConsumerStatefulWidget {
  const TeriyaScoreApp({super.key});

  @override
  ConsumerState<TeriyaScoreApp> createState() => _TeriyaScoreAppState();
}

class _TeriyaScoreAppState extends ConsumerState<TeriyaScoreApp>
    with WidgetsBindingObserver {
  bool _brandIntroDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _resyncThemeTokens() {
    final themePref = ref.read(uxPrefsProvider).theme;
    final platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    ref.read(uxPrefsProvider.notifier).syncPlatformBrightness(platform);
    TsTokens.applyThemeMode(themePref, platformBrightness: platform);
  }

  @override
  void didChangePlatformBrightness() {
    _resyncThemeTokens();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resyncThemeTokens();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // White-label : charge /branding (no-op si hors ligne).
    final branding = ref.watch(brandingProvider);
    final router = ref.watch(routerProvider);
    final uxPrefs = ref.watch(uxPrefsProvider);
    final themePref = uxPrefs.theme;
    TsTokens.applyThemeMode(themePref);
    final themeMode = _themeModeFor(themePref);

    if (!_brandIntroDone) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BrandSplashView(
          onFinished: () {
            if (!mounted) return;
            setState(() => _brandIntroDone = true);
          },
        ),
      );
    }

    return MaterialApp.router(
      key: ValueKey(
        'brand:${branding.hasValue ? TsTokens.appName : 'loading'}:$themePref',
      ),
      title: TsTokens.appName,
      debugShowCheckedModeBanner: false,
      locale: _materialLocaleFor(uxPrefs.language),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTeriyaScoreTheme(Brightness.light),
      darkTheme: buildTeriyaScoreTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        TsTokens.syncFromThemeBrightness(Theme.of(context).brightness);
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
