// First-run local state for the Início screen: the one-time welcome card
// and the one-time dock coachmark. Stored in SharedPreferences, the storage
// the project already uses. No personal data is collected or persisted.
// See docs/ui/UI_SPEC.md 7.10.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage key for the one-time welcome card.
const String welcomeSeenKey = 'ui_welcome_seen_v1';

/// Storage key for the one-time dock coachmark.
const String coachmarkSeenKey = 'ui_coachmark_seen_v1';

/// Whether the one-time first-run affordances have already been dismissed.
class HomeOnboarding {
  /// Creates the state, defaulting to unseen so both show on first run.
  const HomeOnboarding({this.welcomeSeen = false, this.coachmarkSeen = false});

  /// The welcome card has been dismissed.
  final bool welcomeSeen;

  /// The coachmark has been dismissed.
  final bool coachmarkSeen;

  /// Returns a copy with the given overrides applied.
  HomeOnboarding copyWith({bool? welcomeSeen, bool? coachmarkSeen}) {
    return HomeOnboarding(
      welcomeSeen: welcomeSeen ?? this.welcomeSeen,
      coachmarkSeen: coachmarkSeen ?? this.coachmarkSeen,
    );
  }
}

/// Loads the first-run flags once and updates them optimistically.
class HomeOnboardingNotifier extends Notifier<HomeOnboarding> {
  @override
  HomeOnboarding build() {
    unawaited(_load());
    return const HomeOnboarding();
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      state = HomeOnboarding(
        welcomeSeen: prefs.getBool(welcomeSeenKey) ?? false,
        coachmarkSeen: prefs.getBool(coachmarkSeenKey) ?? false,
      );
    } on Object {
      // Defaults (both unseen) stand when prefs are unavailable.
    }
  }

  /// Dismisses the welcome card for good.
  void dismissWelcome() {
    state = state.copyWith(welcomeSeen: true);
    unawaited(_write(welcomeSeenKey, true));
  }

  /// Dismisses the coachmark for good.
  void dismissCoachmark() {
    state = state.copyWith(coachmarkSeen: true);
    unawaited(_write(coachmarkSeenKey, true));
  }

  Future<void> _write(String key, bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } on Object {
      // The in-memory flag still applies for this run.
    }
  }
}

/// Provides the first-run state of Início.
final NotifierProvider<HomeOnboardingNotifier, HomeOnboarding>
onboardingProvider = NotifierProvider<HomeOnboardingNotifier, HomeOnboarding>(
  HomeOnboardingNotifier.new,
);
