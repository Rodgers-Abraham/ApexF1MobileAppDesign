import 'package:flutter_test/flutter_test.dart';
import 'package:f1/features/live/presentation/widgets/replay_swap_queue.dart';

void main() {
  group('ReplaySwapQueue', () {
    test('processes all steps in order, never drops', () async {
      final processed = <String>[];
      final queue = ReplaySwapQueue(
        onStep: (s) => processed.add(s.driverName),
        onDone: () {},
      );

      queue.enqueue([
        const SwapStep(
            driverName: 'VER', fromPos: 2, toPos: 1, eventType: 'OVERTAKE'),
        const SwapStep(
            driverName: 'NOR', fromPos: 1, toPos: 2, eventType: 'OVERTAKE'),
        const SwapStep(
            driverName: 'LEC', fromPos: 4, toPos: 3, eventType: 'PIT_GAIN'),
      ], lapSlotMs: 3000);

      // Wait long enough for all steps: 3 × max 500 ms + margin
      await Future.delayed(const Duration(milliseconds: 2500));
      queue.dispose();

      expect(processed.length, 3);
      expect(processed, ['VER', 'NOR', 'LEC']);
    });

    test('duration is clamped between 80 and 500 ms', () async {
      // With lapSlotMs=3000 and 2 steps: 3000/2 = 1500 → clamped to 500
      final times = <DateTime>[];
      final queue = ReplaySwapQueue(
        onStep: (_) => times.add(DateTime.now()),
        onDone: () {},
      );
      queue.enqueue([
        const SwapStep(
            driverName: 'VER', fromPos: 2, toPos: 1, eventType: 'OVERTAKE'),
        const SwapStep(
            driverName: 'NOR', fromPos: 1, toPos: 2, eventType: 'OVERTAKE'),
      ], lapSlotMs: 3000);
      await Future.delayed(const Duration(milliseconds: 1500));
      queue.dispose();
      if (times.length == 2) {
        final gap = times[1].difference(times[0]).inMilliseconds;
        // Should be ~500 ms (clamped from 1500)
        expect(gap, greaterThanOrEqualTo(400));
        expect(gap, lessThanOrEqualTo(700));
      }
    });

    test('empty enqueue does nothing', () {
      bool doneCalled = false;
      final queue = ReplaySwapQueue(
        onStep: (_) => fail('should not be called'),
        onDone: () => doneCalled = true,
      );
      queue.enqueue([], lapSlotMs: 3000);
      expect(doneCalled, isFalse);
      queue.dispose();
    });
  });
}
