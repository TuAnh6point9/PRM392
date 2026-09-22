import 'dart:async';
import 'dart:isolate';

// Hiệu chỉnh hằng số này sau khi chạy để mỗi phép tính mất khoảng 3-5 giây.
const int heavyIterations = 1500000000;

// Đồng hồ chung giúp mọi dòng log dùng cùng mốc thời gian kể từ khi chương trình bắt đầu.
final Stopwatch programStopwatch = Stopwatch()..start();

void logLine(String message) {
  print('[${programStopwatch.elapsedMilliseconds}] $message');
}

/// Mô phỏng công việc CPU-bound bằng vòng lặp tính checksum.
///
/// Hàm phải ở top-level để Isolate.run có thể thực thi nó trong isolate khác.
/// Tham số [iterations] hỗ trợ test nhanh; khi thí nghiệm thật, hàm dùng
/// [heavyIterations]. Giá trị checksum được in ra để vòng lặp không bị bỏ qua.
int heavyComputation([int iterations = heavyIterations]) {
  var checksum = 0;

  for (var i = 0; i < iterations; i++) {
    // Phép trộn số học đơn giản nhưng phụ thuộc vào từng vòng lặp.
    checksum = (checksum * 1103515245 + i + 12345) & 0x7fffffff;
  }

  return checksum;
}

class HeartbeatMonitor {
  HeartbeatMonitor(this.caseName);

  final String caseName;
  Timer? _timer;
  int? _previousTickMs;
  int _tickCount = 0;
  int _maxGapMs = 0;

  void start() {
    logLine('$caseName: bật heartbeat mỗi 100 ms.');
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final nowMs = programStopwatch.elapsedMilliseconds;
      final gapMs = _previousTickMs == null ? 0 : nowMs - _previousTickMs!;
      _previousTickMs = nowMs;
      _tickCount++;
      if (gapMs > _maxGapMs) {
        _maxGapMs = gapMs;
      }
      logLine('$caseName: heartbeat #$_tickCount, gapMs=$gapMs');
    });
  }

  void stop() {
    _timer?.cancel();
    logLine(
      '$caseName: dừng heartbeat; ticks=$_tickCount, maxGapMs=$_maxGapMs',
    );
  }
}

Future<void> runOnMainIsolate() async {
  const caseName = 'Trường hợp 1 - main isolate';
  logLine('=== $caseName ===');
  final heartbeat = HeartbeatMonitor(caseName)..start();

  // Chờ vài tick để gap sau đó phản ánh khoảng main isolate bị chặn.
  await Future<void>.delayed(const Duration(milliseconds: 250));

  logLine('$caseName: bắt đầu tính trực tiếp.');
  final stopwatch = Stopwatch()..start();
  final checksum = heavyComputation();
  stopwatch.stop();
  logLine(
    '$caseName: hoàn tất; checksum=$checksum, computeMs=${stopwatch.elapsedMilliseconds}',
  );

  // Cho Timer cơ hội chạy tick đang chờ sau khi main isolate được giải phóng.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  heartbeat.stop();
}

Future<void> runWithIsolate() async {
  const caseName = 'Trường hợp 2 - Isolate.run';
  logLine('=== $caseName ===');
  final heartbeat = HeartbeatMonitor(caseName)..start();

  // Cùng thời gian chuẩn bị như trường hợp 1 để log có thể so sánh.
  await Future<void>.delayed(const Duration(milliseconds: 250));

  logLine('$caseName: bắt đầu tính trong isolate phụ.');
  final stopwatch = Stopwatch()..start();
  final checksum = await Isolate.run(heavyComputation, debugName: 'cpu-worker');
  stopwatch.stop();
  logLine(
    '$caseName: hoàn tất; checksum=$checksum, computeMs=${stopwatch.elapsedMilliseconds}',
  );

  await Future<void>.delayed(const Duration(milliseconds: 250));
  heartbeat.stop();
}

Future<void> main() async {
  logLine('Bắt đầu Step 4; heavyIterations=$heavyIterations.');
  await runOnMainIsolate();
  await runWithIsolate();
  logLine('Kết thúc Step 4.');
}
