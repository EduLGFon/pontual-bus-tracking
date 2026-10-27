import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plain controller cancel completes', (WidgetTester tester) async {
    final StreamController<int> controller = StreamController<int>();
    Timer? timer;
    controller.onListen = () {
      timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => controller.add(1),
      );
    };
    controller.onCancel = () {
      timer?.cancel();
      timer = null;
      scheduleMicrotask(() => controller.close());
    };
    final StreamSubscription<int> sub = controller.stream.listen((_) {});
    await tester.pump(const Duration(seconds: 1));
    await sub.cancel();
  });
}
