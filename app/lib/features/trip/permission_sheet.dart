// S07 permission education and denied states. The OS permission request
// itself is owned by LocationService (T31); these sheets cover the
// education, denied, permanently-denied, and services-off states.
// See PLAN.md S07.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';

/// Location permission states relevant to sharing.
enum LocationPermissionState {
  /// Not yet requested or requestable again.
  denied,

  /// Denied with "don't ask again"; only settings help.
  permanentlyDenied,

  /// Granted by the user.
  granted,
}

/// Gateway to the OS permission APIs. Implemented with geolocator in T31;
/// faked in tests.
abstract class PermissionGateway {
  /// Current permission state without prompting.
  Future<LocationPermissionState> check();

  /// Requests the permission, showing the OS dialog.
  Future<LocationPermissionState> request();

  /// True when device location services are on.
  Future<bool> servicesOn();

  /// True when the grant includes precise (full-accuracy) location.
  /// Approximate-only grants report coarse fixes that never pass the
  /// publish gate, so the flow can ask for Precise instead of stalling
  /// at "waiting for GPS". Fail-open: unknown status or any error
  /// answers true and sharing proceeds as today. See D67.
  Future<bool> preciseAccuracy();

  /// Opens the app settings page.
  Future<void> openSettings();
}

/// Pre-prompt education sheet shown before the OS dialog.
class PermissionInfoSheet extends StatelessWidget {
  /// Creates the education sheet.
  const PermissionInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Para compartilhar, o app precisa da localização enquanto '
              'estiver em uso. Nós não pedimos localização o tempo todo.',
              style: context.text.body,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Denied-state sheet with retry and cancel.
class PermissionDeniedSheet extends StatelessWidget {
  /// Creates the denied sheet.
  const PermissionDeniedSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Sem permissão de localização. Sem ela não dá para '
              'compartilhar a viagem.',
              style: context.text.body,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tentar de novo'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Permanently-denied sheet directing to settings.
class PermissionBlockedSheet extends StatelessWidget {
  /// Creates the blocked sheet.
  const PermissionBlockedSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Sem permissão de localização. Sem ela não dá para '
              'compartilhar a viagem.',
              style: context.text.body,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Abrir ajustes'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Location-services-off sheet.
class LocationOffSheet extends StatelessWidget {
  /// Creates the location-off sheet.
  const LocationOffSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Ative a localização do aparelho.', style: context.text.body),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Abrir ajustes'),
            ),
          ],
        ),
      ),
    );
  }
}
