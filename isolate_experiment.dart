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

  print('\n=== CPU-bound bang Isolate.run() ===');
  final isolateStopwatch = Stopwatch()..start();
  final isolateChecksum = await Isolate.run(heavyComputation);
  isolateStopwatch.stop();
  print('Checksum: $isolateChecksum');
  print('Thoi gian: ${isolateStopwatch.elapsedMilliseconds} ms');

  print('\nChecksum giong nhau: ${directChecksum == isolateChecksum}');
}
