import 'package:flutter_test/flutter_test.dart';
import 'package:lenga_app/logic/problem_source.dart';
import 'package:lenga_app/models/problem.dart';
import 'package:lenga_app/services/platform_bridge.dart';

void main() {
  test('parseBatch keeps correct problems, drops wrong, malformed and duplicate ones', () {
    const raw = 'Sure! Here you go:\n'
        '[{"text":"7 × 8 = ?","answer":56},'
        '{"text":"7 × 8 = ?","answer":56},'
        '{"text":"9 × 9 = ?","answer":80},'
        '{"text":"Solve for x: 3x + 4 = 19","answer":5},'
        '{"nonsense":true}]';
    expect(OnDeviceAiGenerator.parseBatch(raw), const [
      Problem('7 × 8 = ?', 56),
      Problem('Solve for x: 3x + 4 = 19', 5),
    ]);
  });

  test('parseBatch tolerates garbage', () {
    expect(OnDeviceAiGenerator.parseBatch('no json here'), isEmpty);
    expect(OnDeviceAiGenerator.parseBatch('[not json]'), isEmpty);
    expect(OnDeviceAiGenerator.parseBatch('{"text":"1 + 1 = ?","answer":2}'), isEmpty);
  });

  test('refill pushes only validated problems when the model is available', () async {
    final bridge = MemoryPlatformBridge(aiAvailability: AiAvailability.available)
      ..aiResponse = '[{"text":"2 + 3 = ?","answer":5},{"text":"2 + 3 = ?","answer":6}]';
    final added = await OnDeviceAiGenerator(bridge, bridge).refill(Difficulty.easy);
    expect(added, 1);
    expect(bridge.queue[Difficulty.easy], const [Problem('2 + 3 = ?', 5)]);
  });

  test('refill does nothing when the model is unavailable or the queue is full', () async {
    final off = MemoryPlatformBridge()..aiResponse = '[{"text":"2 + 3 = ?","answer":5}]';
    expect(await OnDeviceAiGenerator(off, off).refill(Difficulty.easy), 0);

    final full = MemoryPlatformBridge(aiAvailability: AiAvailability.available)
      ..aiResponse = '[{"text":"2 + 3 = ?","answer":5}]'
      ..queue[Difficulty.easy] = List.filled(OnDeviceAiGenerator.targetQueueSize, const Problem('1 + 1 = ?', 2));
    expect(await OnDeviceAiGenerator(full, full).refill(Difficulty.easy), 0);
  });

  test('QueuedProblemSource serves the queue first, then falls back to local', () async {
    final bridge = MemoryPlatformBridge()..queue[Difficulty.easy] = [const Problem('1 + 1 = ?', 2)];
    final source = QueuedProblemSource(bridge, LocalGenerator());
    expect(await source.next(Difficulty.easy), const Problem('1 + 1 = ?', 2));
    final fallback = await source.next(Difficulty.easy);
    expect(fallback.text, contains('+'));
  });
}
