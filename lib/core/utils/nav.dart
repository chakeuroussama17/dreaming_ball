import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation helpers that make the back arrow and the Android system back
/// button behave consistently across the app.
///
/// The app navigates to leaf/detail screens with `pushNamed` so they sit on
/// top of the stack and can be popped. Top-level tabs (home, leaderboard,
/// private room, profile) and auth transitions still use `goNamed` (replace).
///
/// `safePop` pops when there is something to pop, otherwise it falls back to a
/// sensible route — so a screen reached by a deep link or a `goNamed` replace
/// never leaves the user stranded with a dead back button.
extension SafeNav on BuildContext {
  void safePop([String fallbackRoute = 'home']) {
    if (canPop()) {
      pop();
    } else {
      goNamed(fallbackRoute);
    }
  }
}
