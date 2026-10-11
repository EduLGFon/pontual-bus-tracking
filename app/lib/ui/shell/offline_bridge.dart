// Offline flag bridge. The data layer already owns connectivity; this only
// surfaces a banner. No plugin is added by the UI layer.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the app is offline. The banner shows instead of blocking.
final Provider<bool> offlineFlagProvider = Provider<bool>((Ref ref) => false);
