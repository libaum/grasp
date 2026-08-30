import 'dart:math';

import '../models/rating.dart';
import '../models/sr_state.dart';

/// Spaced Repetition auf Basis der Selbsteinschätzung – vereinfachtes SM-2.
///
/// „nochmal" setzt das Intervall auf 0: der Zusammenhang kommt noch in
/// derselben Session wieder, ans Ende der Warteschlange.
///
/// Intervalle sind bei [maxIntervalDays] gedeckelt – ein Zusammenhang, den man
/// ein Jahr lang nicht angefasst hat, soll wieder auftauchen.
const int maxIntervalDays = 365;
SrState nextSrState(SrState current, Rating rating, {DateTime? today}) {
  final now = dateOnly(today ?? DateTime.now());
  var ease = current.ease;
  int interval;

  switch (rating) {
    case Rating.again:
      ease -= 0.2;
      interval = 0;
    case Rating.shaky:
      ease -= 0.05;
      interval = max(1, (max(current.intervalDays, 1) * 1.2).round());
    case Rating.solid:
      ease += 0.05;
      interval = max(1, (max(current.intervalDays, 1) * ease).round());
  }

  ease = ease.clamp(SrState.minEase, SrState.maxEase);
  interval = min(interval, maxIntervalDays);

  return SrState(
    dueDate: now.add(Duration(days: interval)),
    intervalDays: interval,
    ease: ease,
    reps: current.reps + 1,
  );
}
