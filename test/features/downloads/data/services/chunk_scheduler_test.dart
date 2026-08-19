import 'package:app/features/downloads/data/services/chunk_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('executes each item once with bounded concurrency', () async {
    const scheduler = ChunkScheduler(concurrency: 2);
    final completed = <int>[];
    var active = 0;
    var peakActive = 0;

    await scheduler.run<int>(
      items: [0, 1, 2, 3, 4],
      execute: (item) async {
        active++;
        peakActive = active > peakActive ? active : peakActive;
        await Future<void>.delayed(Duration.zero);
        completed.add(item);
        active--;
      },
    );

    expect(completed, unorderedEquals([0, 1, 2, 3, 4]));
    expect(completed.toSet(), hasLength(5));
    expect(peakActive, lessThanOrEqualTo(2));
  });

  test('pause stops assigning new items', () async {
    const scheduler = ChunkScheduler(concurrency: 1);
    var paused = false;
    final completed = <int>[];

    await scheduler.run<int>(
      items: [0, 1, 2],
      isPaused: () => paused,
      execute: (item) async {
        completed.add(item);
        paused = true;
      },
    );

    expect(completed, [0]);
  });
}
