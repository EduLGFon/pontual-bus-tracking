// Bootstrap. runApp happens immediately: no await before the first frame,
// everything else is initialised after it. See PLAN.md 8.4 and
// docs/ui/UI_SPEC.md 11.3.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/prefs/theme_store.dart';
import 'package:pontual/ui/design/adapters/theme_bridge.dart';
import 'package:pontual/ui/router/app_router.dart';

/// Entry point of the app.
void main() {
  runApp(const ProviderScope(child: PontualApp()));
}

/// Application root.
class PontualApp extends ConsumerStatefulWidget {
  /// Creates the application root.
  const PontualApp({super.key});

  @override
  ConsumerState<PontualApp> createState() => _PontualAppState();
}

class _PontualAppState extends ConsumerState<PontualApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadTheme());
    _afterFirstFrame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // PLAN.md 9.5 S03: live dots refresh on resumed, never on a timer.
      unawaited(ref.read(liveRefresherProvider).refresh());
    }
  }

  /// Reads the persisted theme after the first frame, so the first paint
  /// never waits on storage.
  Future<void> _loadTheme() async {
    try {
      final ThemeMode saved = await const ThemeStore().read();
      if (!mounted) {
        return;
      }
      unawaited(ref.read(themeHostProvider.notifier).set(saved));
    } on Object {
      // System default stands.
    }
  }

  /// Runs the deferred work that must not block the first frame.
  void _afterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Edge-to-edge drawing under transparent system bars (UI_SPEC 8).
      // SafeArea in every screen keeps content clear of notches and bars.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Static data stays bundled: lines render from the asset bundle and
      // the remote check is handled by the data layer itself.
      ref.read(linesProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode mode = ref.watch(themeHostProvider);
    return pontualApp(mode: mode, router: buildUiRouter());
  }
}
