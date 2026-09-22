import 'dart:isolate';

// Dieu chinh hang so nay de phep tinh mat khoang 3-5 giay tren may chay.
const int heavyIterations = 1500000000;

// Ham top-level de Isolate.run co the chay no trong isolate phu.
// Tra ve checksum de ket qua vong lap duoc su dung.
int heavyComputation([int iterations = heavyIterations]) {
  var checksum = 0;

  for (var i = 0; i < iterations; i++) {
    checksum = (checksum * 1103515245 + i + 12345) & 0x7fffffff;
  }

  return checksum;
}

Future<void> main() async {
  print('=== CPU-bound tren main isolate ===');
  final directStopwatch = Stopwatch()..start();
  final directChecksum = heavyComputation();
  directStopwatch.stop();
  print('Checksum: $directChecksum');
  print('Thoi gian: ${directStopwatch.elapsedMilliseconds} ms');
  print('Lenh nay chi chay sau khi phep tinh tren main isolate ket thuc.');

  print('\n=== CPU-bound bang Isolate.run() ===');
  final isolateStopwatch = Stopwatch()..start();
  final isolateFuture = Isolate.run(heavyComputation);
  // Isolate.run() tra ve Future ngay; main isolate van co the chay lenh nay.
  print('Main isolate van xu ly duoc lenh nay trong khi isolate phu tinh toan.');
  final isolateChecksum = await isolateFuture;
  isolateStopwatch.stop();
  print('Checksum: $isolateChecksum');
  print('Thoi gian: ${isolateStopwatch.elapsedMilliseconds} ms');

  print('\nChecksum giong nhau: ${directChecksum == isolateChecksum}');
}
