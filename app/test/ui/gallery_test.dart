// Gallery smoke test: every design-system component builds in one tree
// without exceptions. Fixed pumps only: the shared live pulse never
// settles by design, so pumpAndSettle would hang.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/design/gallery/gallery_screen.dart';
import 'package:pontual/ui/design/theme/theme.dart';

void main() {
  testWidgets('gallery builds every component', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: pontualLightTheme(), home: const GalleryScreen()),
    );
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(GalleryScreen), findsOneWidget);
  });

  testWidgets('gallery builds in dark mode', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: pontualDarkTheme(), home: const GalleryScreen()),
    );
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });
}
