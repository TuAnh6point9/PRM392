import '../step2_sync.dart';

void main() {
  // Bắt lỗi nếu hàm đồng bộ trả về trước khi khoảng chờ hoàn tất.
  final stopwatch = Stopwatch()..start();
  downloadFileSync(delay: const Duration(milliseconds: 20));
  stopwatch.stop();

  assert(stopwatch.elapsedMilliseconds >= 15);
  print('PASS: downloadFileSync chặn cho đến khi khoảng chờ kết thúc.');
}
