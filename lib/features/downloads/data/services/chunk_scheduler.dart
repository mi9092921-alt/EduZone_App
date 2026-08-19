/// Schedules independent work items with bounded concurrency.
///
/// The scheduler deliberately does not know about retry policy, persistence,
/// encryption, or transport. The caller owns those concerns in the worker
/// callback, which keeps scheduling deterministic and testable.
class ChunkScheduler {
  const ChunkScheduler({required this.concurrency})
      : assert(concurrency > 0);

  final int concurrency;

  Future<void> run<T>({
    required List<T> items,
    required Future<void> Function(T item) execute,
    bool Function()? isPaused,
  }) async {
    if (items.isEmpty) return;

    var nextIndex = 0;
    final workerCount = concurrency < items.length ? concurrency : items.length;

    Future<void> worker() async {
      while (true) {
        if (isPaused?.call() ?? false) return;
        if (nextIndex >= items.length) return;
        final item = items[nextIndex++];
        await execute(item);
      }
    }

    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
  }
}
