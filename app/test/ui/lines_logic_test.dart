// Tests for the Linhas grouping and sorting. No widgets.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/domain/line_category.dart';
import 'package:pontual/ui/features/lines/lines_logic.dart';
import 'package:pontual/ui/models/line_vm.dart';

LineVM vm(String short, String name, {List<String> terminals = const <String>[]}) {
  return LineVM(
    key: short,
    name: name,
    short: short,
    terminals: terminals,
  );
}

void main() {
  test('sorts UFES first, then Guriri, then Aroeira, then other', () {
    final List<LineVM> sorted = sortedByCategory(<LineVM>[
      vm('71', 'Norte Sul', terminals: const <String>['Norte', 'Sul']),
      vm('13', 'Aroeira / Cohab'),
      vm('70', 'Guriri via Praiano'),
      vm('66', 'Centro / IFES / UFES'),
    ]);
    expect(sorted.map((LineVM l) => l.short), <String?>['66', '70', '13', '71']);
  });

  test('sorts by line number inside a group', () {
    final List<LineVM> sorted = sortedByCategory(<LineVM>[
      vm('64', 'Villages / Roberto Silvares'),
      vm('60', 'Litorâneo / Aviação'),
      vm('66', 'Centro / IFES / UFES'),
      vm('62', 'Guriri / IFES / UFES'),
    ]);
    expect(
      sorted.map((LineVM l) => l.short),
      <String?>['60', '62', '64', '66'],
    );
  });

  test('grouped lines emit headers with counts', () {
    final List<LinesListItem> items = groupedLines(<LineVM>[
      vm('66', 'Centro / IFES / UFES'),
      vm('70', 'Guriri via Praiano'),
      vm('71', 'Norte Sul'),
    ]);
    expect(items.length, 6);
    expect(items[0], isA<LinesHeaderItem>());
    expect((items[0] as LinesHeaderItem).category, LineCategory.ufes);
    expect((items[0] as LinesHeaderItem).count, 1);
    expect((items[1] as LinesLineItem).line.short, '66');
    expect((items[2] as LinesHeaderItem).category, LineCategory.guriri);
    expect((items[4] as LinesHeaderItem).category, LineCategory.other);
  });

  test('live and favourite states never affect the order', () {
    const LineVM live = LineVM(
      key: '71',
      name: 'Norte Sul',
      short: '71',
      isLive: true,
      liveVehicleCount: 2,
    );
    final List<LineVM> sorted = sortedByCategory(<LineVM>[
      live,
      vm('66', 'Centro / IFES / UFES'),
    ]);
    expect(sorted.first.short, '66');
  });
}
