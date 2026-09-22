# Optimizing User Experience Through Asynchronous Programming and Isolates in Dart

## Mã nguồn và cách chạy

```sh
dart run step2_sync.dart
dart run step3_async.dart
dart run isolate_experiment.dart
```

| Tệp | Nội dung | Log chạy thật |
| --- | --- | --- |
| `step2_sync.dart` | Lời gọi đồng bộ chặn main isolate | `step2_sync_run.log` |
| `step3_async.dart` | Mô phỏng I/O-bound bằng Future/`async`/`await` | `step3_async_run.log` |
| `isolate_experiment.dart` | CPU-bound trực tiếp và qua `Isolate.run()` | `step4_isolate_run.log` |

Mỗi chương trình dùng `Stopwatch`, heartbeat `Timer.periodic` 100 ms và log dạng `[<ms>] <nội dung>`. Các số liệu dưới đây lấy từ lần chạy thật bằng Dart SDK 3.13.2 trên Windows x64; chúng có thể thay đổi theo máy, tải hệ thống và chế độ JIT.

## The Problem

Dart bắt đầu chương trình trong main isolate. Mỗi isolate có event loop, xử lý lần lượt các sự kiện đang chờ. Trong Flutter, hàng đợi đó có thể chứa thao tác người dùng và yêu cầu vẽ khung hình. Khi một lời gọi đồng bộ kéo dài không trả quyền điều khiển, event loop không thể xử lý sự kiện tiếp theo; UI vì thế có thể đứng hoặc rớt khung hình. [Concurrency in Dart](https://dart.dev/language/concurrency)

Thí nghiệm synchronous dùng `sleep` để mô phỏng lời gọi chặn 4 giây. Sau hai heartbeat ban đầu, main isolate bị chặn từ 262 ms đến 4268 ms. Heartbeat kế tiếp có `gapMs=4056`, và lệnh sau `downloadFileSync()` chỉ chạy sau `4007 ms`. Đây là bằng chứng console của UI blocking; `sleep` chỉ là mô phỏng, không phải tải tệp thật.

CPU-bound cũng chặn theo cách tương tự. Khi `heavyComputation` chạy trực tiếp trên main isolate, phép tính mất `3312 ms` và heartbeat có gap `3378 ms`.

## The Asynchronous Solution

I/O-bound dành phần lớn thời gian chờ mạng, đĩa hoặc cơ sở dữ liệu, thay vì dùng CPU tính liên tục. Với Future/`async`/`await`, main isolate có thể nhường thời gian chờ I/O cho event loop; Future hoàn tất sau đó sẽ lên lịch để phần mã sau `await` tiếp tục chạy.

`downloadFileAsync()` dùng `Future.delayed` để mô phỏng một lần chờ I/O 4 giây. Nó trả về Future ngay, nên lệnh ngay sau lời gọi chạy sau `2 ms`, không phải chờ 4 giây. Trong lúc chờ, heartbeat tiếp tục đến #40 trước khi Future hoàn tất tại 4020 ms; toàn bộ tác vụ mất `4015 ms`, với `maxGapMs=110`. Vì vậy, main isolate vẫn phản hồi trong khi chờ I/O. `Future.delayed` chỉ mô phỏng thời gian chờ; không phải một yêu cầu mạng thật.

`async`/`await` không tự chuyển phép tính sang isolate khác. Một vòng lặp CPU nặng vẫn chiếm main isolate nếu nó chạy trước một điểm chờ bất đồng bộ; đây là lý do chỉ dùng `async` không giải quyết UI blocking do CPU-bound.

## The Isolate Solution

Mỗi isolate có vùng nhớ (heap), biến toàn cục và event loop riêng. Các isolate không chia sẻ trạng thái trực tiếp mà giao tiếp qua message, nên worker có thể chạy công việc riêng mà không chiếm event loop của main isolate. [Concurrency in Dart](https://dart.dev/language/concurrency)

`heavyComputation` là hàm top-level, thực hiện 1.500.000.000 vòng lặp và trả checksum. Gọi trực tiếp cho checksum `1197327744` sau `3312 ms`, nhưng tạo gap heartbeat `3378 ms`. `await Isolate.run(heavyComputation)` chạy cùng phép tính ở worker isolate; checksum vẫn là `1197327744`, phép tính mất `4384 ms`, còn heartbeat main isolate tiếp tục từ #3 đến #46 với `maxGapMs=110`.

`Isolate.run()` phù hợp cho một công việc nền đơn lẻ có một kết quả. API tạo worker, chạy callback, trả kết quả hoặc lỗi rồi kết thúc worker. Callback và kết quả phải gửi được giữa các isolate. Việc tạo isolate, khởi động/JIT và truyền dữ liệu có chi phí; với nhiều việc nhỏ lặp lại, nên cân nhắc isolate sống lâu dùng `Isolate.spawn()` và port. [Isolates](https://dart.dev/language/isolates), [Isolate.run API](https://api.dart.dev/dart-isolate/Isolate/run.html)

## Comparison

| Tiêu chí | Synchronous | Asynchronous Future async await | Isolate |
| --- | --- | --- | --- |
| Tác vụ minh họa | Lời gọi tuần tự chặn bằng `sleep` | Mô phỏng chờ I/O bằng `Future.delayed` | CPU-bound: 1.500.000.000 vòng lặp checksum |
| Mô hình thực thi | Mã kế tiếp chờ lời gọi hiện tại kết thúc | Future chờ I/O, event loop vẫn xử lý việc khác | Worker isolate riêng; main isolate nhận kết quả qua Future/message |
| Bằng chứng chạy thật | `elapsedMs=4007`; `maxGapMs=4056` | Lệnh kế tiếp sau `2 ms`; tổng `4015 ms`; `maxGapMs=110` | Direct: `3312 ms`, gap `3378`; `Isolate.run`: `4384 ms`, max gap `110` |
| Main isolate | Bị chặn | Không bị chặn trong lúc chờ I/O | Không bị chặn trong lúc worker tính |
| Khả năng phản hồi | Không phản hồi trong thời gian tác vụ chặn | Vẫn xử lý heartbeat trong thời gian chờ | Vẫn xử lý heartbeat trong thời gian tính CPU |
| Chi phí | Đơn giản nhất | Quản lý Future và lỗi bất đồng bộ | Tạo worker, truyền dữ liệu, chi phí khởi động/JIT |
| Khi nên dùng | Công việc ngắn, tuần tự | I/O-bound như mạng, tệp, database | CPU-bound đủ nặng để ảnh hưởng UI |

## Write a brief report explaining

### Why synchronous execution can cause blocking

Thực thi đồng bộ hoàn thành từng câu lệnh trước khi câu lệnh kế tiếp được chạy. Nếu tác vụ kéo dài, main isolate không quay lại event loop để xử lý UI. Log synchronous cho thấy `sleep` 4 giây tạo heartbeat gap `4056 ms` và trì hoãn câu lệnh sau hàm `4007 ms`.

### Why asynchronous programming is suitable for I/O-bound operations

I/O-bound chủ yếu chờ kết quả ngoài CPU. `await` tạm dừng hàm hiện tại thay vì chặn isolate, nên event loop xử lý được input, khung hình và các Future khác trong thời gian chờ. Log asynchronous có 40 heartbeat trước khi mô phỏng I/O hoàn tất.

### Why async and await do not automatically solve CPU-intensive computation

`async` chỉ thay đổi cách hàm trả Future và `await` chỉ nhường quyền điều khiển tại điểm chờ bất đồng bộ. Vòng lặp CPU nặng không tự tạo điểm chờ và vẫn chạy trên main isolate. Log tính trực tiếp cho thấy heartbeat gap `3378 ms`.

### Why Isolates are suitable for CPU-intensive tasks

Isolate chuyển nơi phép tính chạy: worker isolate chiếm CPU, còn main isolate tiếp tục xử lý event loop. `Isolate.run()` giữ checksum giống phép tính trực tiếp, trong khi max heartbeat gap giảm từ `3378 ms` xuống `110 ms` trong lần chạy này.

### When developers should choose Future async await versus Isolate

Chọn Future/`async`/`await` khi phần lớn thời gian là chờ I/O. Chọn Isolate khi phép tính CPU-bound đủ dài để làm UI kém phản hồi và chi phí truyền dữ liệu là chấp nhận được. Chọn synchronous khi công việc ngắn, tuần tự và không chặn trải nghiệm người dùng.

## Conclusion

Kỹ thuật phù hợp phụ thuộc vào bản chất công việc:

- I/O-bound → Future / `async` / `await`
- CPU-bound → Isolate
- Công việc ngắn, tuần tự → Synchronous

Thí nghiệm xác nhận lời gọi synchronous và phép tính CPU trực tiếp chặn main isolate, Future giúp main isolate phản hồi trong thời gian chờ I/O, còn `Isolate.run()` bảo vệ main isolate khi có phép tính CPU nặng.
