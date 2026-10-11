// PermissionCard: explains a permission state and offers the
// platform-correct action. Android can open settings; the web cannot, so
// the card shows browser steps and a re-check button instead.
// See docs/ui/UI_SPEC.md 5 and 7.7.
import 'package:flutter/material.dart';
import 'package:pontual/platform/web/user_agent.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/platform.dart';

/// State of the location permission, as the panel presents it.
enum PermissionCardState {
  /// Not asked or denied, retryable.
  denied,

  /// Denied with "don't ask again": only settings help.
  blocked,

  /// Device location services are off.
  servicesOff,

  /// Web browser could not get a position.
  browserBlocked,

  /// Notifications denied on Android 13 and newer.
  notificationsDenied,

  /// Context does not allow geolocation at all.
  unsupported,
}

/// Card explaining a permission problem with the right action.
class PermissionCard extends StatelessWidget {
  /// Creates the card.
  const PermissionCard({
    required this.state,
    this.onRetry,
    this.onOpenSettings,
    this.onOpenLines,
    super.key,
  });

  /// Which problem to explain.
  final PermissionCardState state;

  /// Called by the retry action.
  final VoidCallback? onRetry;

  /// Called by the settings action, Android only.
  final VoidCallback? onOpenSettings;

  /// Called by the fallback action, web unsupported contexts.
  final VoidCallback? onOpenLines;

  @override
  Widget build(BuildContext context) {
    final bool web = PlatformInfo.isWeb;
    final bool browserSteps =
        state == PermissionCardState.browserBlocked ||
        (state == PermissionCardState.blocked && web);
    final VoidCallback? openLines = onOpenLines;
    final String message = browserSteps
        ? _browserSteps()
        : _messageOf(state, web);
    final String primaryLabel = browserSteps ? '' : _primaryLabelOf(state, web);
    final VoidCallback? primary = browserSteps
        ? null
        : _primaryAction(state, web);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: context.colors.warningText,
              ),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  UiStrings.permissionDenied,
                  style: context.text.bodyStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          Text(message, style: context.text.body),
          if (browserSteps) ...<Widget>[
            const SizedBox(height: Space.x3),
            const _LockIllustration(),
          ],
          if (primaryLabel.isNotEmpty && primary != null) ...<Widget>[
            const SizedBox(height: Space.x4),
            _Action(label: primaryLabel, onTap: primary),
          ],
          if (browserSteps) ...<Widget>[
            const SizedBox(height: Space.x2),
            _Action(label: UiStrings.alreadyAllowed, onTap: onRetry ?? _noop),
          ],
          if (state == PermissionCardState.unsupported &&
              openLines != null) ...<Widget>[
            const SizedBox(height: Space.x2),
            _Action(label: UiStrings.seeTimetable, onTap: openLines),
          ],
        ],
      ),
    );
  }

  String _messageOf(PermissionCardState state, bool web) {
    if (state == PermissionCardState.servicesOff) {
      return web ? UiStrings.locationOffWeb : UiStrings.locationOff;
    }
    if (state == PermissionCardState.notificationsDenied) {
      return UiStrings.notificationNote;
    }
    if (state == PermissionCardState.unsupported) {
      return UiStrings.unsupported;
    }
    return UiStrings.permissionDenied;
  }

  String _browserSteps() {
    // The user agent is only inspected to choose the right instructions.
    final BrowserFamily family = browserFamilyOf(userAgent());
    return switch (family) {
      BrowserFamily.chromium => UiStrings.unblockChromium,
      BrowserFamily.safari => UiStrings.unblockSafari,
      BrowserFamily.firefox => UiStrings.unblockFirefox,
      BrowserFamily.unknown => UiStrings.unblockGeneric,
    };
  }

  String _primaryLabelOf(PermissionCardState state, bool web) {
    if (state == PermissionCardState.blocked ||
        state == PermissionCardState.servicesOff) {
      return web ? UiStrings.retry : UiStrings.openSettings;
    }
    return UiStrings.retry;
  }

  VoidCallback? _primaryAction(PermissionCardState state, bool web) {
    if (state == PermissionCardState.blocked ||
        state == PermissionCardState.servicesOff) {
      return web ? onRetry : onOpenSettings;
    }
    return onRetry;
  }
}

/// No-op used when a card has no retry callback attached.
void _noop() {}

/// Text action inside the card.
class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  /// Label in pt-BR.
  final String label;

  /// Called on tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x1,
          vertical: Space.x2,
        ),
        child: Text(
          label,
          style: context.text.label.copyWith(color: context.colors.primary),
        ),
      ),
    );
  }
}

/// Static illustration of the browser address bar with the lock icon.
class _LockIllustration extends StatelessWidget {
  const _LockIllustration();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SizedBox(
        width: 200,
        height: 36,
        child: CustomPaint(
          painter: _AddressBarPainter(
            bar: colors.surfaceSunken,
            lock: colors.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// Paints a browser address bar with a lock, no image files.
class _AddressBarPainter extends CustomPainter {
  const _AddressBarPainter({required this.bar, required this.lock});

  /// Bar fill colour.
  final Color bar;

  /// Lock colour.
  final Color lock;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = bar;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.height / 2),
      ),
      fill,
    );
    const double cx = 12;
    const double cy = 18;
    final Paint stroke = Paint()
      ..color = lock
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(cx - 4.5, cy - 3, 9, 8),
        const Radius.circular(2),
      ),
      stroke,
    );
    canvas.drawArc(
      const Rect.fromLTWH(cx - 4, cy - 6, 8, 8),
      3.14159,
      -3.14159,
      false,
      stroke,
    );
  }

  @override
  bool shouldRepaint(_AddressBarPainter oldDelegate) {
    return oldDelegate.bar != bar || oldDelegate.lock != lock;
  }
}
