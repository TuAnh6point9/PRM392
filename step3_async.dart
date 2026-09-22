Future<void> downloadFileAsync() async {
  print(
    'Bat dau tac vu bat dong bo (mo phong tai tep qua mang trong 4 giay)...',
  );

  // Future.delayed mo phong mot tac vu I/O-bound (goi mang, doc DB, tai tep).
  // await chi tam dung ham hien tai; main isolate van ranh de xu ly viec khac.
  await Future.delayed(const Duration(seconds: 4));

  print('Tac vu bat dong bo da hoan thanh.');
}

void main() async {
  final stopwatch = Stopwatch()..start();

  // Khong await ngay: downloadFileAsync() tra ve Future va lenh tiep theo
  // trong main() duoc chay ngay lap tuc, khong doi 4 giay.
  final future = downloadFileAsync();

  print(
    'Lenh ngay sau downloadFileAsync(): ${stopwatch.elapsedMilliseconds} ms '
    '(chay ngay, khong doi tac vu bat dong bo)',
  );

  // Doi Future hoan thanh de thay thoi gian tong cong va gia tri cuoi.
  await future;

  print(
    'Toan bo chuong trinh hoan tat sau: ${stopwatch.elapsedMilliseconds} ms',
  );
  stopwatch.stop();
}
