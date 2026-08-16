import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/agent/agent_pages.dart';
import 'features/auth/app_lock.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/register_forgot.dart';
import 'features/auth/splash_login.dart';
import 'features/home/shell_dashboard.dart';
import 'features/notifications/notifications_page.dart';
import 'features/score_credit_profile.dart';
import 'features/settings/about_page.dart';
import 'features/settings/settings_page.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

GoRouter createRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (!auth.ready) return null;
      final loc = state.matchedLocation;
      final loggingIn = loc == '/login' ||
          loc == '/register' ||
          loc == '/forgot-password' ||
          loc == '/';

      if (!auth.isAuthenticated && !loggingIn) return '/login';
      if (auth.isAuthenticated &&
          (loc == '/' ||
              loc == '/login' ||
              loc == '/register' ||
              loc == '/forgot-password')) {
        return '/app';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) =>
            AppLockGate(child: AppShell(child: child)),
        routes: [
          GoRoute(
            path: '/app',
            builder: (context, state) => const AgentDossiersPage(),
          ),
          GoRoute(
            path: '/app/nouveau',
            builder: (context, state) => const AgentNewDossierPage(),
          ),
          GoRoute(
            path: '/app/sync',
            builder: (context, state) => const AgentSyncPage(),
          ),
          GoRoute(
            path: '/app/profil',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: '/app/dossier/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return AgentDossierDetailPage(row: extra);
          }
          return const AgentDossiersPage();
        },
      ),
      GoRoute(
        path: '/app/notifications',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/app/parametres',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/app/aide',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AboutHelpPage(),
      ),
    ],
  );
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      notifyListeners();
    });
  }
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) => createRouter(ref));
