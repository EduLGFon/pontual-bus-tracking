// /trip screen of the new UI: no map, one soft ring pulse on the hero dot,
// elapsed time in tabular figures, and the end card. PRIVACY: this screen
// shows the vehicle, never the rider, and logs nothing. The TripController
// owns every side effect; this file only reads it and calls its methods.
import 'dart:async';

import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/domain/trip/trip_state.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/platform/web/visibility.dart';
import 'package:pontual/platform/web/wake_lock.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/platform.dart';

import 'trip_end_card.dart';
import 'trip_hero.dart';
import 'trip_status.dart';

import 'package:pontual/ui/shell/trip_host.dart';

import 'trip_flow.dart';

/// /trip route: shows the active trip and attaches the started controller
/// to the trip host. A minimised trip keeps the controller alive so the
/// dock stays usable; an ended one is detached and disposed here.
class TripRoute extends ConsumerStatefulWidget {
  /// Creates the route for [controller].
  const TripRoute({required this.controller, super.key});

  /// Controller started by the share flow.
  final TripController controller;

  @override
  ConsumerState<TripRoute> createState() => _TripRouteState();
}

class _TripRouteState extends ConsumerState<TripRoute> {
  TripHost? _host;

  @override
  void initState() {
    super.initState();
    // Provider writes are forbidden inside widget life-cycles, and ref is
    // unsafe in dispose, so the notifier is captured here and used for
    // both the deferred attach and the detach.
    _host = ref.read(tripHostProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        attachTripController(ref, widget.controller);
      }
    });
  }

  @override
  void dispose() {
    final TripHost? host = _host;
    _host = null;
    if (host != null) {
      detachTripController(host, widget.controller);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TripScreen(controller: widget.controller);
  }
}

/// Active trip screen. Reads the controller through a listenable builder:
/// no setState ever carries controller data.
class TripScreen extends StatefulWidget {
  /// Creates a screen driven by [controller].
  const TripScreen({required this.controller, this.nowMs, super.key});

  /// Trip controller owning the trip.
  final TripController controller;

  /// Clock in milliseconds, injectable for deterministic tests.
  final int Function()? nowMs;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

/// Default clock when none is injected.
int _systemNowMs() => DateTime.now().millisecondsSinceEpoch;

class _TripScreenState extends State<TripScreen> with WidgetsBindingObserver {
  Timer? _visibilityTimer;
  bool _promptOpen = false;
  bool _minimising = false;
  bool _wakeUnsupported = false;
  bool _kudosCounted = false;
  int? _helpedTrips;
  final WebVisibilityTracker _visibility = WebVisibilityTracker();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_maybePrompt);
    if (PlatformInfo.isWeb) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(_holdWakeLock());
      _visibilityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _visibility.check(DateTime.now().millisecondsSinceEpoch);
        if (_visibility.paused && !widget.controller.isWebHidden) {
          widget.controller.setWebHidden(true);
        }
      });
    }
  }

  Future<void> _holdWakeLock() async {
    const WebWakeLock lock = ProdWebWakeLock();
    await lock.enable();
    final bool held = await lock.enabled;
    if (mounted && !held) {
      setState(() {
        _wakeUnsupported = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!PlatformInfo.isWeb) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _visibility.onHidden(DateTime.now().millisecondsSinceEpoch);
    } else if (state == AppLifecycleState.resumed) {
      _visibility.onVisible();
      widget.controller.setWebHidden(false);
    }
  }

  @override
  void dispose() {
    if (PlatformInfo.isWeb) {
      WidgetsBinding.instance.removeObserver(this);
      _visibilityTimer?.cancel();
      unawaited(const ProdWebWakeLock().disable());
    }
    widget.controller.removeListener(_maybePrompt);
    super.dispose();
  }

  /// RF16 prompt: presented when the controller asks, never before.
  void _maybePrompt() {
    if (_promptOpen || !widget.controller.walkingPromptVisible) {
      return;
    }
    _promptOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_showWalking());
      } else {
        _promptOpen = false;
      }
    });
  }

  Future<void> _showWalking() async {
    final TripController c = widget.controller;
    final bool? still = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(UiStrings.walkingTitle, style: context.text.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PrimaryButton(
              label: UiStrings.walkingYes,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Space.x2),
            DangerButton(
              label: UiStrings.walkingNo,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    _promptOpen = false;
    if (!mounted) {
      return;
    }
    if (still == true) {
      c.confirmStillRiding();
    } else {
      await c.confirmLeftBus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final TripController c = widget.controller;
        if (c.endKind != null && c.state is TripIdle) {
          _countKudosOnce();
          return TripEndCard(
            kind: c.endKind!,
            detail: c.endDetail,
            helpedTrips: _helpedTrips,
          );
        }
        return _body(context, c);
      },
    );
  }

  /// Device-only helped-trips counter (D30 extra). Counts once per
  /// screen: the post-frame write keeps it off the build path, and a
  /// rebuild before the read lands never double-counts.
  void _countKudosOnce() {
    if (_kudosCounted) {
      return;
    }
    _kudosCounted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await const KudosStore().addOne();
        final int n = await const KudosStore().read();
        if (mounted) {
          setState(() => _helpedTrips = n);
        }
      } on Object {
        // The end card stands without the counter when prefs fail.
      }
    });
  }

  Widget _body(BuildContext context, TripController c) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop || _minimising) {
          return;
        }
        _minimising = true;
        // System back minimises instead of ending: the dock keeps the trip
        // and the foreground service keeps sharing (UI_SPEC 8).
        context.pop();
      },
      child: Scaffold(
        backgroundColor: context.colors.bg,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: marginFor(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _header(context),
                const SizedBox(height: Space.x4),
                // Single scroll region above the pinned stop action: at
                // large text scales the content scrolls and the button
                // never scrolls away.
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TripHero(
                          key: const ValueKey<String>('tripHeroSection'),
                          controller: c,
                          startedAtMs: c.startedAtMs,
                          nowMs: _nowMs,
                        ),
                        const SizedBox(height: Space.x4),
                        StatusBlock(
                          controller: c,
                          wakeUnsupported: _wakeUnsupported,
                          nowMs: _nowMs,
                        ),
                        const SizedBox(height: Space.x4),
                      ],
                    ),
                  ),
                ),
                _stopBlock(context, c),
                const SizedBox(height: Space.x4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pinned stop action: caption plus a full-width 56 dp button that is
  /// never disabled. One tap ends the trip, online or offline.
  Widget _stopBlock(BuildContext context, TripController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          UiStrings.tripStopCaption,
          style: context.text.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.x2),
        DangerButton(
          key: const ValueKey<String>('tripStop'),
          label: UiStrings.tripStop,
          semanticLabel: UiStrings.tripStopSemantic,
          onPressed: () => unawaited(c.endTrip()),
        ),
      ],
    );
  }

  /// Header with the minimise chevron and the screen title.
  Widget _header(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('tripHeader'),
      padding: const EdgeInsets.only(top: Space.x2),
      child: Row(
        children: <Widget>[
          IconBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            semanticLabel: UiStrings.tripMinimize,
            onTap: () => context.pop(),
          ),
          const SizedBox(width: Space.x2),
          Expanded(child: Text(UiStrings.tripTitle, style: context.text.title)),
        ],
      ),
    );
  }

  int _nowMs() {
    final int Function()? injected = widget.nowMs;
    return injected != null ? injected() : _systemNowMs();
  }
}
