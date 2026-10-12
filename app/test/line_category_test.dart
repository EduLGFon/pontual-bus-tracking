// Tests for the business line categories: explicit map priority,
// text fallback, labels and ordering. No widgets.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/domain/line_category.dart';

void main() {
  test('explicit map wins over text mentions', () {
    expect(
      categoryFor(
        short: '62',
        name: 'Guriri / IFES / UFES',
        terminals: const <String>['Guriri', 'IFES / UFES'],
      ),
      LineCategory.ufes,
    );
    expect(
      categoryFor(
        short: '60',
        name: 'Litorâneo / Aviação',
        terminals: const <String>['Litorâneo', 'Aviação'],
      ),
      LineCategory.ufes,
    );
    expect(
      categoryFor(
        short: '64',
        name: 'Villages / Roberto Silvares',
        terminals: const <String>['Villages', 'Roberto Silvares'],
      ),
      LineCategory.ufes,
    );
  });

  test('guriri lines are yellow, including the 23 assumption', () {
    for (final String short in <String>['701', '70', '23']) {
      expect(
        categoryFor(
          short: short,
          name: 'Guriri',
          terminals: const <String>['Guriri'],
        ),
        LineCategory.guriri,
        reason: 'short $short',
      );
    }
  });

  test('text fallback is accent-insensitive', () {
    expect(
      categoryFor(
        short: '999',
        name: 'Centro / Ifes / Ufes',
        terminals: const <String>['Centro'],
      ),
      LineCategory.ufes,
    );
    expect(
      categoryFor(
        short: '999',
        name: 'Aroeira / Cohab',
        terminals: const <String>['Aroeira', 'Cohab'],
      ),
      LineCategory.aroeira,
    );
    expect(
      categoryFor(
        short: '12',
        name: 'Aroeira / Roberto Silvares',
        terminals: const <String>['Aroeira', 'Roberto Silvares'],
      ),
      LineCategory.aroeira,
    );
  });

  test('unknown lines are other and never throw', () {
    expect(
      categoryFor(
        short: '71',
        name: 'Norte Sul',
        terminals: const <String>['Norte', 'Sul'],
      ),
      LineCategory.other,
    );
    expect(
      categoryFor(short: '', name: '', terminals: const <String>[]),
      LineCategory.other,
    );
  });

  test('labels and order put UFES first and other last', () {
    expect(lineCategoryLabel(LineCategory.ufes), 'UFES / IFES');
    expect(lineCategoryLabel(LineCategory.guriri), 'Guriri');
    expect(lineCategoryLabel(LineCategory.other), 'Outras');
    expect(
      lineCategoryOrder(LineCategory.ufes) <
          lineCategoryOrder(LineCategory.guriri),
      isTrue,
    );
    expect(
      lineCategoryOrder(LineCategory.guriri) <
          lineCategoryOrder(LineCategory.other),
      isTrue,
    );
  });
}
