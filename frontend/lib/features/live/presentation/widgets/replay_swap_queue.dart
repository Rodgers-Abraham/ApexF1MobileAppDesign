import 'dart:async';
import 'dart:collection';

/// One position change that happened at a lap boundary.
class SwapStep {
  final String driverName;
  final int fromPos;
  final int toPos;

  /// 'OVERTAKE' | 'PIT_GAIN' | 'RETIREMENT_GAIN'
  final String eventType;
  final String label;

  const SwapStep({
    required this.driverName,
    required this.fromPos,
    required this.toPos,
    required this.eventType,
    this.label = '',
  });
}

/// Processes a queue of [SwapStep]s one at a time with a configurable duration.
/// Never drops a step — if new steps arrive while processing, they are appended.
///
/// Duration per step: min(500 ms, lapSlotMs / stepCount), floor 80 ms.
class ReplaySwapQueue {
  final Queue<SwapStep> _queue = Queue();
  Timer? _timer;
  final void Function(SwapStep step) onStep;
  final void Function() onDone;

  ReplaySwapQueue({required this.onStep, required this.onDone});

  /// Enqueue a batch of swaps to animate.
  /// [lapSlotMs]: time in ms until the next lap fires at the current speed.
  void enqueue(List<SwapStep> steps, {required int lapSlotMs}) {
    if (steps.isEmpty) return;
    _queue.addAll(steps);
    _maybeStart(lapSlotMs);
  }

  void _maybeStart(int lapSlotMs) {
    if (_timer != null && _timer!.isActive) return;
    _processNext(lapSlotMs);
  }

  void _processNext(int lapSlotMs) {
    if (_queue.isEmpty) {
      onDone();
      return;
    }
    final step = _queue.removeFirst();
    onStep(step);
    // Duration: min(500, lapSlot / remaining+1), floor 80
    final remaining = _queue.length + 1;
    final ms = (lapSlotMs ~/ remaining).clamp(80, 500);
    _timer = Timer(Duration(milliseconds: ms), () => _processNext(lapSlotMs));
  }

  void dispose() {
    _timer?.cancel();
    _queue.clear();
  }
}
