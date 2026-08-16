import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_provider.dart';
import '../api/client.dart';
import '../offline/local_cache.dart';
import '../theme/tokens.dart';
import 'strings.dart';

/// Préférences UX locales (langue + thème).
class UxPrefs {
  const UxPrefs({
    this.language = 'fr',
    // Clair par défaut : sur Android, « system » suit aussi l'économiseur
    // d'énergie (mode nuit), ce qui bascule l'app en sombre à tort.
    this.theme = 'light',
  });

  final String language;

  /// `system` | `light` | `dark`
  final String theme;

  UxPrefs copyWith({
    String? language,
    String? theme,
  }) =>
      UxPrefs(
        language: language ?? this.language,
        theme: theme ?? this.theme,
      );
}

class UxPrefsNotifier extends StateNotifier<UxPrefs> {
  UxPrefsNotifier(this._ref) : super(const UxPrefs()) {
    _hydrate();
    _ref.listen<AuthState>(authProvider, (prev, next) {
      final theme = next.user?.theme;
      final prevTheme = prev?.user?.theme;
      if (theme != null && theme.isNotEmpty && theme != prevTheme) {
        syncThemeFromUser(theme);
      }
    });
  }

  final Ref _ref;

  TsStrings get strings => TsStrings(state.language);

  void _hydrate() {
    try {
      final cached = _ref.read(localCacheProvider).getMap(LocalCacheKeys.uxPrefs);
      if (cached != null) {
        var theme = cached.containsKey('theme')
            ? _normalizeTheme(cached['theme']?.toString())
            : 'light';
        final migrated = cached['themeDefaultV2'] == true;
        if (!migrated && theme == 'system') theme = 'light';
        state = UxPrefs(
          language: TsStrings.normalize(cached['language']?.toString()),
          theme: theme,
        );
      }
    } catch (_) {
      // LocalCache not ready yet — défaut clair
    }
    final user = _ref.read(authProvider).user;
    final lang = user?.language;
    if (lang != null && lang.isNotEmpty) {
      state = state.copyWith(language: TsStrings.normalize(lang));
    }
    final theme = user?.theme;
    if (theme != null && theme.isNotEmpty) {
      final normalized = _normalizeTheme(theme);
      if (normalized != 'system') {
        state = state.copyWith(theme: normalized);
      }
    }
    _applyTokens(state.theme);
    Future(() => _saveLocal(state));
  }

  /// `system` | `light` | `dark` — défaut clair.
  static String _normalizeTheme(String? value) {
    if (value == 'light' || value == 'dark' || value == 'system') return value!;
    return 'light';
  }

  void _applyTokens(String theme) {
    TsTokens.applyThemeMode(theme);
  }

  Future<void> _saveLocal(UxPrefs prefs) async {
    try {
      await _ref.read(localCacheProvider).putMap(LocalCacheKeys.uxPrefs, {
        'language': prefs.language,
        'theme': prefs.theme,
        'themeDefaultV2': true,
      });
    } catch (_) {}
  }

  void setLanguageLocal(String lang) {
    state = state.copyWith(language: TsStrings.normalize(lang));
    _saveLocal(state);
  }

  void setThemeLocal(String theme) {
    final next = _normalizeTheme(theme);
    state = state.copyWith(theme: next);
    _applyTokens(next);
    _saveLocal(state);
  }

  /// Applique le thème renvoyé par l'API (/me, login).
  void syncThemeFromUser(String? theme) {
    if (theme == null || theme.isEmpty) return;
    final next = _normalizeTheme(theme);
    if (next == 'system' &&
        (state.theme == 'light' || state.theme == 'dark')) {
      return;
    }
    if (next == state.theme) return;
    state = state.copyWith(theme: next);
    _applyTokens(next);
    _saveLocal(state);
  }

  /// Recalcule les tokens quand le thème téléphone change (mode système).
  void syncPlatformBrightness(Brightness brightness) {
    if (state.theme != 'system') return;
    TsTokens.applyThemeMode('system', platformBrightness: brightness);
  }

  Future<void> persist({
    String? language,
    String? theme,
  }) async {
    final next = state.copyWith(
      language: language != null ? TsStrings.normalize(language) : null,
      theme: theme != null ? _normalizeTheme(theme) : null,
    );
    state = next;
    if (theme != null) _applyTokens(next.theme);
    await _saveLocal(next);
    try {
      await _ref
          .read(apiClientProvider)
          .patch(
            '/me/preferences',
            data: {
              if (language != null) 'language': TsStrings.normalize(language),
              if (theme != null) 'theme': _normalizeTheme(theme),
            },
          );
      final user = _ref.read(authProvider).user;
      if (user != null && (language != null || theme != null)) {
        _ref.read(authProvider.notifier).setUser(
              user.copyWith(
                language: language != null
                    ? TsStrings.normalize(language)
                    : user.language,
                theme: theme != null ? _normalizeTheme(theme) : user.theme,
              ),
            );
      }
    } catch (_) {
      // Préférence locale conservée hors ligne
    }
  }
}

final uxPrefsProvider = StateNotifierProvider<UxPrefsNotifier, UxPrefs>((ref) {
  return UxPrefsNotifier(ref);
});

final tsStringsProvider = Provider<TsStrings>((ref) {
  final lang = ref.watch(uxPrefsProvider).language;
  return TsStrings(lang);
});
