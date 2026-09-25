import '../step4_isolate.dart';

void main() {
  // Kết quả cố định với input nhỏ, dùng để kiểm tra hàm tính toán thực sự
  // trả checksum thay vì bỏ qua giá trị vòng lặp.
  assert(heavyComputation(10) == 1525987651);
  print('PASS: heavyComputation(10) trả về checksum đã biết.');
}
