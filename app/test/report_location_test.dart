// One-shot report location: permission states, accuracy gate and area
// conversion. The exact fix never escapes the service.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/features/reports/report_location.dart';
import 'package:pontual/features/trip/permission_sheet.dart';

class FakeGateway implements PermissionGateway {
  FakeGateway({
    this.checkState = LocationPermissionState.granted,
    this.requestState = LocationPermissionState.granted,
    this.services = true,
  });

  LocationPermissionState checkState;
  LocationPermissionState requestState;
  bool services;
  int requests = 0;
  int opens = 0;

  @override
  Future<LocationPermissionState> check() async => checkState;

  @override
  Future<LocationPermissionState> request() async {
    requests += 1;
    checkState = requestState;
    return requestState;
  }

  @override
  Future<bool> servicesOn() async => services;

  @override
  Future<bool> preciseAccuracy() async => true;

  @override
  Future<void> openSettings() async {
    opens += 1;
  }
}

ReportLocationService serviceWith(
  FakeGateway gateway, {
  double accuracyM = 20,
  Future<ReportFix> Function()? readFix,
}) {
  return ReportLocationService(
    gateway: gateway,
    readFix:
        readFix ??
        () async => (lat: -18.7156, lng: -39.8568, accuracyM: accuracyM),
  );
}

void main() {
  test('granted permission yields a coarse cell', () async {
    final ReportAreaResult result = await serviceWith(FakeGateway()).acquire();
    expect(result, isA<ReportAreaOk>());
    expect((result as ReportAreaOk).areaId, 'g52902_98514');
  });

  test('a denied prompt can be retried into a grant', () async {
    final FakeGateway gateway = FakeGateway(
      checkState: LocationPermissionState.denied,
      requestState: LocationPermissionState.granted,
    );
    final ReportAreaResult result = await serviceWith(gateway).acquire();
    expect(result, isA<ReportAreaOk>());
    expect(gateway.requests, 1);
  });

  test('denied and blocked states are distinct', () async {
    final FakeGateway denied = FakeGateway(
      checkState: LocationPermissionState.denied,
      requestState: LocationPermissionState.denied,
    );
    expect(
      ((await serviceWith(denied).acquire()) as ReportAreaError).reason,
      ReportLocationFailure.denied,
    );
    final FakeGateway blocked = FakeGateway(
      checkState: LocationPermissionState.permanentlyDenied,
    );
    expect(
      ((await serviceWith(blocked).acquire()) as ReportAreaError).reason,
      ReportLocationFailure.blocked,
    );
    expect(blocked.requests, 0);
  });

  test('a fix outside the served area is rejected', () async {
    final ReportAreaResult result = await serviceWith(
      FakeGateway(),
      readFix: () async => (lat: 0.0, lng: 0.0, accuracyM: 10.0),
    ).acquire();
    expect(
      (result as ReportAreaError).reason,
      ReportLocationFailure.outsideArea,
    );
  });

  test('services off, coarse fixes and timeouts fail honestly', () async {
    final FakeGateway off = FakeGateway(services: false);
    expect(
      ((await serviceWith(off).acquire()) as ReportAreaError).reason,
      ReportLocationFailure.servicesOff,
    );
    expect(
      ((await serviceWith(FakeGateway(), accuracyM: 300).acquire())
              as ReportAreaError)
          .reason,
      ReportLocationFailure.imprecise,
    );
    expect(
      ((await serviceWith(
                FakeGateway(),
                readFix: () async => throw TimeoutException('slow'),
              ).acquire())
              as ReportAreaError)
          .reason,
      ReportLocationFailure.timeout,
    );
    expect(
      ((await serviceWith(
                FakeGateway(),
                readFix: () async => throw StateError('boom'),
              ).acquire())
              as ReportAreaError)
          .reason,
      ReportLocationFailure.unknown,
    );
  });
}
