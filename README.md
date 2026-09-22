# Optimizing User Experience Through Asynchronous Programming and Isolates in Dart

## Mã nguồn và cách chạy

```sh
dart run step2_sync.dart
dart run step3_async.dart
dart run isolate_experiment.dart
```

| Tệp | Nội dung |
| --- | --- |
| `step2_sync.dart` | Thí nghiệm thực thi đồng bộ. |
| `step3_async.dart` | Thí nghiệm I/O-bound mô phỏng với Future/`async`/`await`. |
| `isolate_experiment.dart` | Thí nghiệm CPU-bound trực tiếp và bằng `Isolate.run()`. |

Các thời gian dưới đây được đo bằng `Stopwatch` trong một lần chạy bằng Dart SDK 3.13.2 trên Windows x64. Kết quả có thể khác theo máy và chế độ JIT.

## The Problem

Dart bắt đầu chương trình trong main isolate. Main isolate xử lý các sự kiện của event loop theo thứ tự; trong Flutter, đó có thể là thao tác người dùng và yêu cầu vẽ khung hình. Nếu một lời gọi đồng bộ kéo dài, main isolate không thể xử lý sự kiện tiếp theo cho đến khi lời gọi kết thúc. Đây là nguyên nhân UI blocking. [Concurrency in Dart](https://dart.dev/language/concurrency)

`downloadFileSync()` dùng `sleep` để mô phỏng một tác vụ chặn 4 giây. Trong lần chạy thật, lệnh ngay sau `downloadFileSync()` chỉ xuất hiện sau `4005 ms`. Dù đây không phải thao tác tải tệp thật, nó cho thấy lời gọi đồng bộ chặn mã theo sau và sẽ làm UI không phản hồi nếu chạy trên main isolate.

## The Asynchronous Solution

I/O-bound dành phần lớn thời gian chờ mạng, tệp hoặc cơ sở dữ liệu thay vì tính toán liên tục trên CPU. Future/`async`/`await` cho phép main isolate nhường thời gian chờ cho event loop; khi I/O hoàn tất, Future được hoàn thành và mã sau `await` tiếp tục chạy.

`downloadFileAsync()` dùng `Future.delayed` để mô phỏng một lần chờ I/O 4 giây. Hàm trả về Future ngay nên lệnh ngay sau lời gọi xuất hiện sau `7 ms`; toàn bộ tác vụ kết thúc sau `4026 ms`. `Future.delayed` chỉ mô phỏng thời gian chờ, không phải một yêu cầu mạng thật.

`async`/`await` không tự chuyển phép tính sang isolate khác. Một vòng lặp CPU nặng vẫn chạy liên tục trên main isolate nếu nó không gặp thao tác bất đồng bộ thực sự, nên vẫn có thể gây UI blocking.

## The Isolate Solution

Mỗi isolate có vùng nhớ (heap), event loop và trạng thái riêng. Isolate không chia sẻ trạng thái trực tiếp mà giao tiếp bằng message. Vì vậy, một worker isolate có thể thực hiện CPU-bound mà không chiếm event loop của main isolate. [Concurrency in Dart](https://dart.dev/language/concurrency)

`heavyComputation` là hàm top-level, thực hiện 1.500.000.000 vòng lặp và trả checksum. Chạy trực tiếp trên main isolate mất `2790 ms`; dòng mã theo sau chỉ in sau khi phép tính này kết thúc. Khi khởi chạy cùng phép tính bằng `Isolate.run(heavyComputation)`, dòng từ main isolate in ngay trước khi `await` kết quả; toàn bộ tác vụ mất `3828 ms`. Hai cách đều trả checksum `1197327744`, xác nhận chúng thực hiện cùng phép tính.

`Isolate.run()` phù hợp với một công việc nền đơn lẻ có một kết quả. Đổi lại, việc tạo worker isolate, khởi động/JIT và truyền dữ liệu tạo thêm chi phí. Callback và kết quả phải gửi được giữa các isolate. [Isolates](https://dart.dev/language/isolates), [Isolate.run API](https://api.dart.dev/dart-isolate/Isolate/run.html)

## Comparison

| Tiêu chí | Synchronous | Asynchronous Future async await | Isolate |
| --- | --- | --- | --- |
| Tác vụ minh họa | Lời gọi chặn bằng `sleep` | Mô phỏng chờ I/O bằng `Future.delayed` | CPU-bound với 1.500.000.000 vòng lặp |
| Program response time | Lệnh sau hàm chạy sau `4005 ms` | Lệnh sau hàm chạy sau `7 ms`; tác vụ hoàn tất sau `4026 ms` | Direct: `2790 ms`; dòng main chỉ chạy sau khi tính xong. `Isolate.run`: `3828 ms`; dòng main chạy ngay sau khi khởi tạo Future. |
| Main isolate | Bị chặn cho đến khi hàm kết thúc | Có thể xử lý sự kiện khác trong lúc Future chờ | Không chạy phép tính nặng khi worker isolate xử lý |
| UI responsiveness | Bị đứng nếu chạy trên UI isolate | Vẫn phản hồi trong thời gian chờ I/O | Vẫn phản hồi khi CPU-bound chạy ở worker isolate |
| Execution model | Tuần tự trong main isolate | Event loop chờ Future hoàn tất | Isolate phụ có heap và event loop riêng |
| Khi nên dùng | Công việc ngắn, tuần tự | I/O-bound: mạng, tệp, database | CPU-bound đủ nặng để ảnh hưởng UI |

## Write a brief report explaining

### Why synchronous execution can cause blocking

Mã synchronous chạy từng câu lệnh theo thứ tự. Lời gọi hiện tại phải hoàn thành trước khi main isolate quay lại event loop. Vì vậy, tác vụ kéo dài làm chậm mã theo sau và ngăn UI xử lý tương tác hoặc vẽ khung hình mới.

### Why asynchronous programming is suitable for I/O-bound operations

Với I/O-bound, CPU thường không bận mà chỉ chờ dữ liệu từ bên ngoài. `await` tạm dừng hàm hiện tại thay vì chặn toàn bộ isolate, nên event loop có thể xử lý công việc khác trong lúc chờ.

### Why async and await do not automatically solve CPU-intensive computation

`async` chỉ làm hàm trả về Future; nó không đổi isolate thực thi của vòng lặp CPU. Nếu vòng lặp không nhường quyền điều khiển, nó vẫn chiếm main isolate đến khi hoàn tất.

### Why Isolates are suitable for CPU-intensive tasks

Isolate di chuyển phép tính sang worker có heap và event loop riêng. Main isolate không phải thực hiện vòng lặp nặng, nên có thể tiếp tục xử lý các sự kiện UI.

### When developers should choose Future async await versus Isolate

Chọn Future/`async`/`await` cho I/O-bound. Chọn Isolate cho CPU-bound đủ nặng để làm UI chậm. Với công việc ngắn, tuần tự, synchronous đơn giản hơn.

## Conclusion

- I/O-bound → Future / `async` / `await`
- CPU-bound → Isolate
- Công việc ngắn, tuần tự → Synchronous

Chọn kỹ thuật đúng theo loại tác vụ giúp chương trình giữ được khả năng phản hồi mà không thêm chi phí đồng thời không cần thiết.
