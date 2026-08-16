import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../sync/sync_service.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sync = ref.read(syncServiceProvider);
      sync.startAutoSync();
      sync.flush();
      ref.read(uxPrefsProvider.notifier).setLanguageLocal('fr');
    });
  }

  int _indexForLocation(String loc) {
    if (loc.startsWith('/app/nouveau')) return 1;
    if (loc.startsWith('/app/sync')) return 2;
    if (loc.startsWith('/app/profil')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(loc);
    final t = ref.watch(tsStringsProvider);

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && index != 0) context.go('/app');
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: index,
          backgroundColor: TsTokens.surface,
          indicatorColor: TsTokens.brand.withValues(alpha: 0.25),
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                context.go('/app');
              case 1:
                context.go('/app/nouveau');
              case 2:
                context.go('/app/sync');
              case 3:
                context.go('/app/profil');
            }
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.folder_outlined, size: 24),
              selectedIcon: Icon(Icons.folder, size: 24),
              label: t('dossiers'),
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline, size: 24),
              selectedIcon: Icon(Icons.add_circle, size: 24),
              label: t('newDossier'),
            ),
            NavigationDestination(
              icon: Icon(Icons.sync_outlined, size: 24),
              selectedIcon: Icon(Icons.sync, size: 24),
              label: t('sync'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, size: 24),
              label: t('profile'),
            ),
          ],
        ),
      ),
    );
  }
}
