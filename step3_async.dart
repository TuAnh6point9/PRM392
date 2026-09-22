import 'dart:async';

const Duration simulatedIoDelay = Duration(seconds: 4);
final Stopwatch programStopwatch = Stopwatch()..start();

void logLine(String message) {
  print('[${programStopwatch.elapsedMilliseconds}] $message');
}

/// Mô phỏng I/O-bound: Future.delayed không chiếm CPU trong thời gian chờ.
Future<void> downloadFileAsync({Duration delay = simulatedIoDelay}) async {
  logLine(
    'Bắt đầu tác vụ bất đồng bộ; mô phỏng chờ tệp trong ${delay.inMilliseconds} ms.',
  );
  await Future<void>.delayed(delay);
  logLine('Tác vụ bất đồng bộ đã hoàn thành.');
}

class HeartbeatMonitor {
  Timer? _timer;
  int? _previousTickMs;
  int _ticks = 0;
  int _maxGapMs = 0;

  void start() {
    logLine('Heartbeat bật, chu kỳ 100 ms.');
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final nowMs = programStopwatch.elapsedMilliseconds;
      final gapMs = _previousTickMs == null ? 0 : nowMs - _previousTickMs!;
      _previousTickMs = nowMs;
      _ticks++;
      if (gapMs > _maxGapMs) _maxGapMs = gapMs;
      logLine('Heartbeat #$_ticks, gapMs=$gapMs');
    });
  }

  void stop() {
    _timer?.cancel();
    logLine('Dừng heartbeat; ticks=$_ticks, maxGapMs=$_maxGapMs');
  }
}

Future<void> main() async {
  logLine('Bắt đầu Step 3 - Asynchronous.');
  final heartbeat = HeartbeatMonitor()..start();
  final stopwatch = Stopwatch()..start();

  // Không await ngay: main isolate có thể tiếp tục chạy và xử lý heartbeat.
  final future = downloadFileAsync();
  logLine(
    'Lệnh ngay sau downloadFileAsync(); elapsedMs=${stopwatch.elapsedMilliseconds}.',
  );

  await future;
  stopwatch.stop();
  logLine(
    'Toàn bộ tác vụ bất đồng bộ hoàn tất; elapsedMs=${stopwatch.elapsedMilliseconds}.',
  );

  await Future<void>.delayed(const Duration(milliseconds: 250));
  heartbeat.stop();
  logLine('Kết thúc Step 3.');
}
