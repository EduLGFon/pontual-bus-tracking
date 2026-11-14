// /trip screen of the new UI: no map, one soft ring pulse on the hero dot,
// elapsed time in tabular figures, and the end card. PRIVACY: this screen
// shows the vehicle, never the rider, and logs nothing. The TripController
// owns every side effect; this file only reads it and calls its methods.
import 'dart:async';

import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/config/env.dart';
import 'package:pontual/domain/trip/trip_state.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/platform/screen_wake.dart';
import 'package:pontual/platform/web/visibility.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/features/reports/report_sheet.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/shell/trip_host.dart';
import 'package:pontual/ui/util/platform.dart';

import 'trip_end_card.dart';
import 'trip_flow.dart';
import 'trip_hero.dart';
import 'trip_status.dart';

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
  const TripScreen({
    required this.controller,
    this.nowMs,
    this.showForcePing = forcePingButton,
    this.isWeb,
    this.screenWake,
    super.key,
  });

  /// Trip controller owning the trip.
  final TripController controller;

  /// Clock in milliseconds, injectable for deterministic tests.
  final int Function()? nowMs;

  /// Shows the test-only force-ping button. Defaults to the
  /// FORCE_PING_BUTTON dart-define (false), so production builds never
  /// render it. Tests pass true explicitly.
  final bool showForcePing;

  /// Overrides web detection for tests. Null follows the real platform.
  final bool? isWeb;

  /// Screen wake implementation, injectable for tests.
  final ScreenWake? screenWake;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

/// Default clock when none is injected.
int _systemNowMs() => DateTime.now().millisecondsSinceEpoch;

class _TripScreenState extends State<TripScreen> with WidgetsBindingObserver {
  /// One coarse 5 s clock for the hero and the status block, which each
  /// used to own a timer. It pauses while the app is not resumed: the trip
  /// process stays alive under the foreground service, so background ticks
  /// would only rebuild an invisible screen.
  Timer? _ticker;
  bool _promptOpen = false;
  bool _wakeUnsupported = false;
  bool _kudosCounted = false;
  bool _screenOn = false;
  int? _helpedTrips;
  final WebVisibilityTracker _visibility = WebVisibilityTracker();
  late final ScreenWake _screenWake;

  bool get _isWeb => widget.isWeb ?? PlatformInfo.isWeb;

  /// Android and web offer the screen-on toggle. Android starts off so
  /// the foreground service keeps sharing with the screen locked.
  bool get _supportsScreenOn => _isWeb || PlatformInfo.isAndroid;

  @override
  void initState() {
    super.initState();
    _screenWake = widget.screenWake ?? const ProdScreenWake();
    widget.controller.addListener(_maybePrompt);
    // The observer runs on every platform: it pauses the coarse clock in
    // the background and drives the web visibility tracker.
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    if (_isWeb) {
      // Web trips acquire the wake lock automatically; the toggle only
      // lets the rider release and reacquire it.
      _screenOn = true;
      unawaited(_acquireScreenWake());
    }
  }

  /// Requests the wake lock and mirrors the platform result in the
  /// toggle. A refusal turns the toggle back off and shows the caption.
  Future<void> _acquireScreenWake() async {
    if (!tripInProgress(widget.controller.state)) {
      return;
    }
    await _screenWake.enable();
    final bool held = await _screenWake.enabled;
    if (!mounted) {
      return;
    }
    setState(() {
      _screenOn = held;
      _wakeUnsupported = !held;
    });
  }

  /// Turns the screen-on intent on or off. Android defaults to off, so
  /// sharing continues with the screen locked until the rider opts in.
  Future<void> _toggleScreenOn() async {
    if (_screenOn) {
      setState(() {
        _screenOn = false;
        _wakeUnsupported = false;
      });
      await _screenWake.disable();
      return;
    }
    await _acquireScreenWake();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stopTicker();
      if (_isWeb) {
        _visibility.onHidden(_nowMs());
      }
      return;
    }
    _startTicker();
    if (!_isWeb) {
      _tick();
      return;
    }
    // Order matters on web: clearing the hidden state first keeps the tick
    // from pausing a session that is being resumed.
    final int nowMs = _nowMs();
    final int hiddenForMs = _visibility.hiddenFor(nowMs);
    _visibility.onVisible();
    _tick();
    unawaited(_recoverWeb(hiddenForMs));
  }

  /// Re-acquires the wake lock only when the rider left it on, and asks
  /// the controller for a fresh fix. Both are best effort: the existing
  /// stream and the stall watchdog remain the fallback.
  Future<void> _recoverWeb(int hiddenForMs) async {
    if (_screenOn) {
      unawaited(_acquireScreenWake());
    }
    await widget.controller.recoverWebSharing(hiddenForMs: hiddenForMs);
  }

  @override
  void dispose() {
    _stopTicker();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_screenWake.disable());
    widget.controller.removeListener(_maybePrompt);
    super.dispose();
  }

  /// Starts the coarse clock, if it is not already running.
  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  /// Stops the coarse clock: nothing visible needs it off foreground.
  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// One coarse tick. The rebuild refreshes the time texts (elapsed,
  /// last-send, stale tier) and, on web, feeds the visibility tracker.
  void _tick() {
    if (!mounted) {
      return;
    }
    setState(() {});
    if (!_isWeb) {
      return;
    }
    final int nowMs = _nowMs();
    _visibility.check(nowMs);
    if (_visibility.paused && !widget.controller.isWebHidden) {
      widget.controller.setWebHidden(true);
    }
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
      // A pushed /trip has the screen that opened it below, so system back
      // pops to it instead of ending, and the dock keeps sharing
      // (UI_SPEC 8, DECISIONS.md#D77). Without a previous route (test
      // harness, future deep link) the handler falls back to home.
      // Navigator, not the go_router helper: TripScreen is also mounted
      // in plain MaterialApp harnesses that have no GoRouter above them.
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) {
          return;
        }
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: context.colors.bg,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: marginFor(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The stop action is pinned in bottomNavigationBar below, so
                // the header scrolls with the content: at large text scales the
                // full title stays visible instead of being clipped.
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _header(context, c),
                        const SizedBox(height: Space.x4),
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
                          screenOn: _screenOn,
                          isWeb: _isWeb,
                          nowMs: _nowMs,
                        ),
                        if (_supportsScreenOn) ...<Widget>[
                          const SizedBox(height: Space.x3),
                          _screenOnBlock(context),
                        ],
                        const SizedBox(height: Space.x4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: marginFor(context)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.x4),
              child: _stopBlock(context, c),
            ),
          ),
        ),
      ),
    );
  }

  /// Full-width screen-on toggle. It is the rider's opt-in on Android
  /// and a release/reacquire control on the web. A refused request turns
  /// the toggle off and shows one short caption.
  Widget _screenOnBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SecondaryButton(
          key: const ValueKey<String>('tripScreenOn'),
          label: _screenOn ? UiStrings.screenOnOn : UiStrings.screenOnOff,
          icon: _screenOn
              ? Icons.light_mode_rounded
              : Icons.light_mode_outlined,
          semanticLabel: _screenOn
              ? UiStrings.screenOnOnSemantic
              : UiStrings.screenOnOffSemantic,
          onPressed: () => unawaited(_toggleScreenOn()),
        ),
        if (_wakeUnsupported) ...<Widget>[
          const SizedBox(height: Space.x2),
          Text(
            UiStrings.screenOnUnsupported,
            style: context.text.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Pinned stop action: caption plus a full-width 56 dp button that is
  /// never disabled. One tap ends the trip, online or offline.
  Widget _stopBlock(BuildContext context, TripController c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final int? lineId = c.lineId;
            if (lineId == null || !ref.watch(appFeaturesProvider).reports) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SecondaryButton(
                  key: const ValueKey<String>('tripReport'),
                  label: UiStrings.reportTripAction,
                  icon: Icons.flag_rounded,
                  semanticLabel: UiStrings.reportTripSemantic,
                  onPressed: () => unawaited(
                    showReportSheet(
                      context,
                      lineId: lineId,
                      lineName: c.lineLabel,
                      onSubmitted: () =>
                          ref.read(vehicleRepoProvider(lineId)).refresh(),
                    ),
                  ),
                ),
                const SizedBox(height: Space.x2),
              ],
            );
          },
        ),
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
        // Test-only force-ping button. Gated by showForcePing (dart-define
        // FORCE_PING_BUTTON, default false), so it never renders in
        // production builds.
        if (widget.showForcePing) ...<Widget>[
          const SizedBox(height: Space.x2),
          SecondaryButton(
            key: const ValueKey<String>('forcePing'),
            label: UiStrings.forcePingTest,
            compact: true,
            onPressed: () => _forcePing(context, c),
          ),
        ],
      ],
    );
  }

  /// Queues one immediate ping and toasts the result. Test builds only.
  void _forcePing(BuildContext context, TripController c) {
    final bool sent = c.forcePingNow();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          sent ? UiStrings.forcePingSent : UiStrings.forcePingNoFix,
        ),
      ),
    );
  }

  /// Header with the minimise chevron and the screen title. Minimising
  /// pops back to the screen that opened the trip, so the line details
  /// (or the tab, or search) return with their state intact. The live trip
  /// stays attached to the trip host, so the dock keeps working and
  /// sharing continues. Home is only the fallback when there is no route
  /// to pop.
  Widget _header(BuildContext context, TripController c) {
    return Padding(
      key: const ValueKey<String>('tripHeader'),
      padding: const EdgeInsets.only(top: Space.x2),
      child: Row(
        children: <Widget>[
          IconBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            semanticLabel: UiStrings.tripMinimize,
            onTap: _minimize,
          ),
          const SizedBox(width: Space.x2),
          Expanded(child: Text(UiStrings.tripTitle, style: context.text.title)),
        ],
      ),
    );
  }

  /// Leaves the trip screen without ending the trip. Pops when there is a
  /// screen to return to; a deep link or a bare harness falls back home.
  void _minimize() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  int _nowMs() {
    final int Function()? injected = widget.nowMs;
    return injected != null ? injected() : _systemNowMs();
  }
}
