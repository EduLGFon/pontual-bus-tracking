// Coarse report area math. Mirrors the server test vectors.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/domain/reporting/report_area.dart';

void main() {
  test('known coordinates map to the same cells as the server', () {
    expect(reportAreaOf(-18.7156, -39.8568), 'g52902_98514');
    expect(reportAreaOf(-18.73276, -39.97248), 'g52889_98433');
    expect(reportAreaOf(-18.73849, -39.75091), 'g52885_98588');
  });

  test('cell centers round-trip inside the cell', () {
    const String id = 'g52902_98514';
    final ReportAreaCenter? center = reportAreaCenterOf(id);
    expect(center, isNotNull);
    expect(reportAreaOf(center!.lat, center.lng), id);
    expect(reportAreaDistanceM(id, center.lat, center.lng), lessThan(1));
  });

  test('invalid ids are rejected and distances stay optional', () {
    expect(isValidReportArea('g52902_98514'), isTrue);
    expect(isValidReportArea('nope'), isFalse);
    expect(isValidReportArea('g_1'), isFalse);
    expect(reportAreaCenterOf('nope'), isNull);
    expect(reportAreaDistanceM('nope', -18.7, -39.8), isNull);
    expect(isReportAreaInServedBBox('g52902_98514'), isTrue);
    expect(isReportAreaInServedBBox('g0_0'), isFalse);
    expect(reportAreaDistanceM('g52902_98514', -18.72, -39.86), greaterThan(0));
  });
}
