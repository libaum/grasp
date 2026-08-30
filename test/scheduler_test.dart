import 'package:flutter_test/flutter_test.dart';
import 'package:grasp/models/rating.dart';
import 'package:grasp/models/sr_state.dart';
import 'package:grasp/services/scheduler.dart';

void main() {
  final today = DateTime(2026, 8, 30);

  test('fresh state ist sofort fällig', () {
    expect(SrState.fresh(today: today).isDue(today: today), isTrue);
  });

  test('"nochmal" hält den Zusammenhang in derselben Session', () {
    final next = nextSrState(SrState.fresh(today: today), Rating.again,
        today: today);
    expect(next.intervalDays, 0);
    expect(next.isDue(today: today), isTrue);
    expect(next.ease, closeTo(2.1, 1e-9));
  });

  test('"saß gut" verlängert die Intervalle', () {
    var sr = SrState.fresh(today: today);
    final intervals = <int>[];
    for (var i = 0; i < 4; i++) {
      sr = nextSrState(sr, Rating.solid, today: today);
      intervals.add(sr.intervalDays);
    }
    expect(intervals.first, greaterThanOrEqualTo(1));
    for (var i = 1; i < intervals.length; i++) {
      expect(intervals[i], greaterThan(intervals[i - 1]));
    }
    expect(sr.isDue(today: today), isFalse);
  });

  test('"wackelig" wächst langsamer als "saß gut"', () {
    final start = SrState(
        dueDate: today, intervalDays: 10, ease: 2.3, reps: 3);
    final shaky = nextSrState(start, Rating.shaky, today: today);
    final solid = nextSrState(start, Rating.solid, today: today);
    expect(shaky.intervalDays, lessThan(solid.intervalDays));
    expect(shaky.intervalDays, greaterThan(start.intervalDays));
  });

  test('ease bleibt in den Grenzen', () {
    var sr = SrState.fresh(today: today);
    for (var i = 0; i < 20; i++) {
      sr = nextSrState(sr, Rating.again, today: today);
    }
    expect(sr.ease, SrState.minEase);
    for (var i = 0; i < 40; i++) {
      sr = nextSrState(sr, Rating.solid, today: today);
    }
    expect(sr.ease, SrState.maxEase);
    expect(sr.intervalDays, maxIntervalDays);
  });

  test('reps zählen jeden Versuch', () {
    var sr = SrState.fresh(today: today);
    sr = nextSrState(sr, Rating.again, today: today);
    sr = nextSrState(sr, Rating.solid, today: today);
    expect(sr.reps, 2);
  });
}
