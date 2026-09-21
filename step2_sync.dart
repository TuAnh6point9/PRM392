import 'dart:io';

void downloadFileSync() {
  print('Bat dau tac vu dong bo (mo phong tai tep trong 4 giay)...');

  // sleep chan main isolate; day la mo phong, khong tai tep that.
  sleep(const Duration(seconds: 4));

  print('Tac vu dong bo da hoan thanh.');
}

void main() {
  final stopwatch = Stopwatch()..start();

  downloadFileSync();

  // Lenh nay chi duoc chay sau khi downloadFileSync() ket thuc.
  print('Lenh ngay sau downloadFileSync(): ${stopwatch.elapsedMilliseconds} ms');
  stopwatch.stop();
}
