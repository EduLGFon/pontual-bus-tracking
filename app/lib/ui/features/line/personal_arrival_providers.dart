// Riverpod wiring for the personal arrival feature on the line screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/core/geo/geo.dart' as core;
import 'package:pontual/domain/learning/eta_estimate.dart';
import 'package:pontual/domain/learning/learned_stop.dart';
import 'package:pontual/ui/adapters/personal_arrival.dart';
import 'package:pontual/ui/adapters/vehicles_adapter.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/features/line/viewer_location.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

/// Personal arrival view model for one line.
final personalArrivalProvider = Provider.autoDispose
    .family<PersonalArrivalVM, int>((Ref ref, int lineId) {
      final ViewerFixState fix = ref.watch(viewerFixProvider);
      if (fix.position == null) {
        return const PersonalArrivalVM(
          status: PersonalArrivalStatus.needsLocation,
        );
      }
      final core.LatLng viewer = core.LatLng(
        fix.position!.latitude,
        fix.position!.longitude,
      );
      final AsyncValue<LearnedStopsResult?> stopsAsync = ref.watch(
        learnedStopsProvider(lineId),
      );
      final List<LearnedStop> stops =
          stopsAsync.value?.stops ?? const <LearnedStop>[];
      final List<VehicleVM> vehicles = ref.watch(vehiclesVmProvider(lineId));
      final LearnedStop? nearest = nearestStopOf(viewer, stops);
      EtaResult? eta;
      bool etaLoading = false;
      bool etaFailed = false;
      if (nearest != null &&
          vehicles.any((VehicleVM v) => v.certainty == Certainty.live)) {
        final AsyncValue<EtaResult?> etaAsync = ref.watch(
          etaProvider((lineId: lineId, stopId: nearest.id)),
        );
        eta = etaAsync.value;
        etaLoading = etaAsync.isLoading && eta == null;
        etaFailed = etaAsync.hasError && eta == null;
      }
      return buildPersonalArrival(
        viewer: viewer,
        now: DateTime.now(),
        fixAt: fix.at,
        stopsLoading: stopsAsync.isLoading && !stopsAsync.hasValue,
        stops: stops,
        vehicles: vehicles,
        eta: eta,
        etaLoading: etaLoading,
        etaFailed: etaFailed,
      );
    });

/// Throttled ETA refresher widget.
class PersonalArrivalRefresher extends ConsumerStatefulWidget {
  /// Creates the refresher.
  const PersonalArrivalRefresher({
    required this.lineId,
    required this.stopId,
    super.key,
  });

  /// Line id.
  final int lineId;

  /// Stop id.
  final String stopId;

  @override
  /// Creates the state.
  ConsumerState<PersonalArrivalRefresher> createState() =>
      _PersonalArrivalRefresherState();
}

/// State for [PersonalArrivalRefresher].
/// State for the refresher.
class _PersonalArrivalRefresherState
    extends ConsumerState<PersonalArrivalRefresher> {
  DateTime? _last;

  @override
  void initState() {
    super.initState();
    _last = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<int>>(vehicleTickProvider, (_, _) {
      final bool dataSaver = ref.read(settingsProvider).dataSaver;
      if (dataSaver) {
        return;
      }
      if (ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      final DateTime now = DateTime.now();
      if (_last != null &&
          now.difference(_last!).inSeconds < personalEtaRefreshS) {
        return;
      }
      _last = now;
      ref.invalidate(
        etaProvider((lineId: widget.lineId, stopId: widget.stopId)),
      );
    });
    return const SizedBox.shrink();
  }
}
