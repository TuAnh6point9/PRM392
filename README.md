# Optimizing User Experience Through Asynchronous Programming and Isolates in Dart

Bài thực hành minh họa cách lựa chọn giữa thực thi đồng bộ, `Future`/`async`/`await` và Isolate trong Dart. Ba chương trình chạy độc lập trên console; kết quả được dùng để giải thích ảnh hưởng của từng cách tiếp cận đến main isolate và khả năng phản hồi của giao diện Flutter.

## Thành viên nhóm

| Mã sinh viên | Họ và tên | Email |
| --- | --- | --- |
| DE190747 | Vương Minh Quân | quanvuong22122005@gmail.com |
| DE190555 | Nguyễn Đình Anh Tuấn | nguyendinhanhtuan0609@gmail.com |
| DE190063 | Phạm Lê Quốc Thông | thongphamle.22.12@gmail.com |
| DE190429 | Nguyễn Thân Thành Đạt | doraemondat0605@gmail.com |

## Mã nguồn và cách chạy

```sh
dart run step2_sync.dart
dart run step3_async.dart
dart run step4_isolate.dart
```

| Tệp | Nội dung |
| --- | --- |
| `step2_sync.dart` | Thí nghiệm thực thi đồng bộ với `downloadFileSync()`. |
| `step3_async.dart` | Thí nghiệm I/O-bound với `downloadFileAsync()`, `Future`, `async` và `await`. |
| `step4_isolate.dart` | Thí nghiệm CPU-bound trên main isolate và bằng `Isolate.run()`. |

Các số liệu trong báo cáo được lấy từ một lần chạy thật bằng Dart ở chế độ JIT trên Windows x64. Thời gian có thể thay đổi theo máy, tải hệ thống và phiên bản Dart; bài không yêu cầu nộp file log riêng.

Yêu cầu Dart 2.19 trở lên để sử dụng `Isolate.run()`.

## Implementation Tasks

### Step 1 Literature Review and Problem Identification

Dart bắt đầu chương trình trong main isolate. Mỗi isolate có một event loop xử lý lần lượt các sự kiện trong hàng đợi. Trong Flutter, các sự kiện đó gồm thao tác người dùng, timer và yêu cầu vẽ khung hình. Nếu main isolate phải chạy một thao tác đồng bộ hoặc phép tính CPU kéo dài, event loop chưa thể xử lý sự kiện tiếp theo, khiến giao diện giật hoặc không phản hồi. [Concurrency in Dart](https://dart.dev/language/concurrency)

I/O-bound là tác vụ dành phần lớn thời gian chờ dữ liệu từ mạng, tệp hoặc cơ sở dữ liệu. CPU-bound là tác vụ dành phần lớn thời gian thực hiện tính toán. `Future`, `async` và `await` phù hợp với thời gian chờ I/O; Isolate phù hợp với phép tính CPU đủ nặng để chặn main isolate.

Các vấn đề cần xác định:

- Nếu một tác vụ đồng bộ kéo dài chạy trên main isolate, UI không thể xử lý tương tác hoặc vẽ khung hình mới cho đến khi tác vụ kết thúc.
- `async`/`await` một mình không giải quyết CPU-bound vì nó không tự chuyển phép tính sang một isolate khác.
- I/O-bound nên dùng API bất đồng bộ với `Future`/`async`/`await`; CPU-bound nên chuyển sang Isolate; công việc ngắn và tuần tự có thể chạy đồng bộ.

### Step 2 Experiment 1 Legacy Approach Synchronous

`step2_sync.dart` định nghĩa `void downloadFileSync()`. Hàm dùng `sleep` để mô phỏng một lời gọi đồng bộ kéo dài 4 giây. Đây là kỹ thuật chặn thay cho việc tải tệp thật và nằm trong lựa chọn “large loop or another blocking technique” của đề.

Kết quả chạy:

```text
Bat dau tac vu dong bo (mo phong tai tep trong 4 giay)...
Tac vu dong bo da hoan thanh.
Lenh ngay sau downloadFileSync(): 4013 ms
```

**Observation:** Lệnh sau `downloadFileSync()` không chạy ngay mà phải đợi khoảng `4013 ms`. Nếu cùng cách gọi này nằm trên main UI isolate của Flutter, event loop bị chặn trong thời gian đó nên ứng dụng có thể bị đứng.

### Step 3 Experiment 2 Modern Approach Asynchronous

`step3_async.dart` định nghĩa `Future<void> downloadFileAsync()` và dùng `Future.delayed()` để mô phỏng một thao tác I/O-bound kéo dài 4 giây. Hàm trả về một `Future`; `main()` giữ Future đó, chạy lệnh tiếp theo rồi mới `await` kết quả.

Kết quả chạy:

```text
Bat dau tac vu bat dong bo (mo phong tai tep qua mang trong 4 giay)...
Lenh ngay sau downloadFileAsync(): 4 ms (chay ngay, khong doi tac vu bat dong bo)
Tac vu bat dong bo da hoan thanh.
Toan bo chuong trinh hoan tat sau: 4011 ms
```

**Observation:** Lệnh kế tiếp trong `main()` chạy sau khoảng `4 ms`, trước khi tác vụ mô phỏng hoàn tất. Khi gặp `await`, chỉ luồng thực thi của hàm hiện tại tạm dừng; event loop vẫn có thể xử lý công việc khác trong thời gian chờ I/O. Vì vậy Future/`async`/`await` giúp UI duy trì khả năng phản hồi đối với tác vụ I/O-bound.

### Step 4 Experiment 3 CPU Intensive Task Isolate

`step4_isolate.dart` định nghĩa hàm top-level `heavyComputation()`, thực hiện `1.500.000.000` vòng lặp và trả checksum để kết quả tính toán được sử dụng. Chương trình chạy cùng phép tính theo hai cách:

1. Gọi trực tiếp trên main isolate.
2. Gọi bằng `Isolate.run(heavyComputation)` trên worker isolate.

Kết quả chạy:

```text
=== CPU-bound tren main isolate ===
Checksum: 1197327744
Thoi gian: 2764 ms
Lenh nay chi chay sau khi phep tinh tren main isolate ket thuc.

=== CPU-bound bang Isolate.run() ===
Main isolate van xu ly duoc lenh nay trong khi isolate phu tinh toan.
Checksum: 1197327744
Thoi gian: 4891 ms

Checksum giong nhau: true
```

**Observation:** Khi gọi trực tiếp, lệnh kế tiếp chỉ chạy sau khi vòng lặp kết thúc, chứng tỏ main isolate bị chặn khoảng `2764 ms`. Với `Isolate.run()`, lời gọi trả về Future và main isolate in được dòng tiếp theo trong khi worker isolate đang tính toán. Hai cách trả cùng checksum `1197327744`, xác nhận chúng thực hiện cùng một phép tính.

Isolate không nhất thiết làm tổng thời gian ngắn hơn. Lần chạy này mất `4891 ms` vì có thêm chi phí tạo worker, khởi động/JIT và truyền kết quả. Lợi ích chính là phép tính CPU không chiếm event loop của main isolate. Mỗi isolate có heap và event loop riêng; các isolate không chia sẻ trạng thái trực tiếp mà giao tiếp bằng message. [Isolates](https://dart.dev/language/isolates) và [Isolate.run API](https://api.dart.dev/dart-isolate/Isolate/run.html)

`async`/`await` không đủ cho phép tính này. Đánh dấu một hàm là `async` chỉ làm hàm trả về Future; vòng lặp CPU vẫn chạy trên isolate đã gọi nó nếu không được chuyển sang Isolate khác.

### Step 5 Comparison and Documentation

| Tiêu chí | Synchronous | Asynchronous Future async await | Isolate |
| --- | --- | --- | --- |
| Task Type | Công việc ngắn, tuần tự; lời gọi chặn | I/O-bound: mạng, tệp, database | CPU-bound: tính toán lớn, xử lý dữ liệu nặng |
| Program Response Time | Lệnh sau hàm chạy sau `4013 ms` | Lệnh sau hàm chạy sau `4 ms`; tác vụ hoàn tất sau `4011 ms` | Direct: `2764 ms`; `Isolate.run`: `4891 ms` |
| Main Isolate Status | Bị chặn cho đến khi hàm hoàn tất | Rảnh trong thời gian Future chờ I/O | Không thực hiện phép tính nặng khi worker isolate xử lý |
| UI Responsiveness | Có thể đứng hoặc giật | Vẫn phản hồi trong thời gian chờ I/O | Vẫn phản hồi trong khi CPU-bound chạy ở worker isolate |
| Execution Model | Tuần tự trên main isolate | Event loop tiếp tục xử lý sự kiện trong lúc chờ Future | Worker có heap và event loop riêng, giao tiếp bằng message |
| Appropriate Use Cases | Phép toán ngắn, đơn giản, cần kết quả ngay | HTTP request, đọc tệp bất đồng bộ, truy vấn database | Parse dữ liệu lớn, mã hóa, xử lý ảnh hoặc tính toán phức tạp |

#### Why synchronous execution can cause blocking

Mã synchronous chạy tuần tự. Một lời gọi kéo dài phải hoàn tất trước khi main isolate quay lại event loop, nên các thao tác người dùng và yêu cầu vẽ UI bị xử lý muộn.

#### Why asynchronous programming is suitable for I/O-bound operations

Trong tác vụ I/O-bound, chương trình chủ yếu chờ hệ điều hành hoặc dịch vụ bên ngoài. Future và `await` cho phép hàm tạm dừng trong thời gian chờ mà không giữ main isolate bận, để event loop tiếp tục xử lý công việc khác.

#### Why async and await do not automatically solve CPU-intensive computation

`async` chỉ thay đổi cách hàm biểu diễn kết quả trong tương lai; nó không thay đổi nơi đoạn mã chạy. Một vòng lặp CPU nặng không có điểm nhường quyền điều khiển vẫn chiếm main isolate cho đến khi hoàn tất.

#### Why Isolates are suitable for CPU-intensive tasks

Worker isolate chạy phép tính bằng heap và event loop riêng, có thể sử dụng lõi CPU khác khi nền tảng cho phép. Vì main isolate không trực tiếp chạy vòng lặp nặng, nó vẫn có thể xử lý các sự kiện UI.

#### When developers should choose Future async await versus Isolate

Chọn Future/`async`/`await` khi tác vụ chủ yếu chờ I/O. Chọn Isolate khi tác vụ chủ yếu dùng CPU và đủ nặng để ảnh hưởng khả năng phản hồi. Chọn synchronous cho công việc ngắn, đơn giản và tuần tự.

## Research Report

### The Problem

Thao tác đồng bộ kéo dài hoặc phép tính CPU nặng chiếm main isolate, làm event loop không thể xử lý kịp thao tác người dùng và yêu cầu vẽ khung hình. Kết quả Step 2 và phần chạy trực tiếp của Step 4 đều cho thấy lệnh tiếp theo chỉ xuất hiện sau khi tác vụ kết thúc.

### The Asynchronous Solution

Future, `async` và `await` cho phép chương trình tiếp tục trong thời gian chờ I/O. Step 3 cho thấy lệnh kế tiếp chạy sau `4 ms`, trong khi Future hoàn tất sau khoảng 4 giây. Cách này cải thiện khả năng phản hồi đối với I/O-bound nhưng không tạo thêm nơi thực thi cho CPU-bound.

### The Isolate Solution

`Isolate.run()` chuyển phép tính CPU sang worker isolate có bộ nhớ và event loop riêng. Main isolate nhận Future và tiếp tục thực hiện lệnh khác trong khi chờ kết quả. Chi phí phải chấp nhận gồm tạo isolate, khởi động/JIT và truyền dữ liệu hoặc kết quả giữa các isolate.

### Comparison

Synchronous đơn giản nhưng tác vụ dài sẽ chặn main isolate. Future/`async`/`await` phù hợp với thời gian chờ I/O và giữ event loop hoạt động. Isolate phù hợp với CPU-bound vì tách phép tính khỏi main isolate, dù có thêm chi phí khởi tạo và truyền message. Bảng ở Step 5 trình bày đầy đủ sáu tiêu chí so sánh của đề.

### Conclusion

- I/O-bound: dùng Future / `async` / `await`.
- CPU-bound đủ nặng để ảnh hưởng UI: dùng Isolate.
- Công việc ngắn, đơn giản và tuần tự: dùng synchronous.

Việc lựa chọn kỹ thuật phụ thuộc vào bản chất tác vụ. Mục tiêu không chỉ là giảm thời gian tổng cộng mà còn là giữ main UI isolate sẵn sàng xử lý sự kiện và vẽ giao diện.
