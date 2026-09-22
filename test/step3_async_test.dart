import '../step3_async.dart';

Future<void> main() async {
  // Bắt lỗi nếu hàm async hoàn tất đồng bộ thay vì trả Future đang chờ I/O.
  var completed = false;
  final future = downloadFileAsync(delay: const Duration(milliseconds: 20));
  future.whenComplete(() => completed = true);

  await Future<void>.delayed(Duration.zero);
  assert(!completed);

  await future;
  assert(completed);
  print('PASS: downloadFileAsync trả Future trước khi khoảng chờ kết thúc.');
}
