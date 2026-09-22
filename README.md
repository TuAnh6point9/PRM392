# Optimizing User Experience Through Asynchronous Programming and Isolates in Dart

## Mã và cách chạy

```sh
dart run step2_sync.dart
dart run isolate_experiment.dart
```

- `step2_sync.dart`: thí nghiệm thực thi đồng bộ.
- `isolate_experiment.dart`: thí nghiệm CPU-bound trên main isolate và bằng `Isolate.run()`.
- `step4_isolate_run.log`: log chạy thật của thí nghiệm Isolate.

## Phạm vi và dữ liệu thí nghiệm hiện có

Tài liệu này dùng chung cho các phần đã hoàn thành của nhóm: thực thi đồng bộ và Isolate. Hiện chưa có mã hoặc log thí nghiệm cho Future/`async`/`await`, nên tài liệu chỉ giải thích phần đó về mặt lý thuyết và không đưa số liệu thực nghiệm cho nó.

Các số liệu trong tài liệu lấy từ lần chạy thật bằng Dart SDK 3.13.2 trên Windows x64. Thời gian có thể thay đổi theo máy, tải hệ thống và chế độ JIT.

## The Problem

Dart chạy mã trong isolate; chương trình bắt đầu ở main isolate. Main isolate có event loop để lấy và xử lý lần lượt các sự kiện đang chờ. Trong ứng dụng Flutter, những sự kiện đó có thể gồm thao tác người dùng và yêu cầu vẽ lại giao diện. Khi một lời gọi đồng bộ kéo dài không trả quyền điều khiển, event loop không thể chuyển sang sự kiện tiếp theo. [Concurrency in Dart](https://dart.dev/language/concurrency)

Thí nghiệm đồng bộ gọi `downloadFileSync()`, dùng `sleep` để mô phỏng một tác vụ chặn trong 4 giây. Lần chạy thật cho thấy dòng lệnh ngay sau lời gọi chỉ xuất hiện sau `4012 ms`. Hàm này không tải tệp thật; nó chứng minh đặc tính tuần tự và chặn của lời gọi đồng bộ. Trong Flutter, một thao tác tương tự chạy trên main isolate sẽ làm giao diện không xử lý tương tác hoặc khung hình mới trong thời gian đó.

Với CPU-bound, hiệu ứng này còn rõ hơn vì phép tính liên tục chiếm CPU. Thí nghiệm `heavyComputation` chạy trực tiếp trên main isolate trong `3071 ms`. Sau khi hai heartbeat đã chạy, khoảng cách đến heartbeat kế tiếp tăng lên `3137 ms`, cho thấy event loop không xử lý `Timer` trong lúc vòng lặp CPU chạy.

## The Asynchronous Solution

Future, `async` và `await` phù hợp cho I/O-bound, tức là công việc chủ yếu chờ mạng, tệp hoặc cơ sở dữ liệu. Khi main isolate gặp `await` của một Future I/O chưa hoàn tất, nó có thể quay lại event loop để xử lý các sự kiện khác. Khi I/O hoàn tất, Future được đưa trở lại hàng đợi và phần mã sau `await` mới tiếp tục chạy.

`async`/`await` một mình không giải quyết UI blocking do CPU-bound. Chúng thay đổi cách mã chờ kết quả, không tự đổi isolate thực thi. Nếu vòng lặp CPU nặng chạy trước điểm `await`, vòng lặp ấy vẫn chiếm main isolate liên tục. Vì vậy, không có cơ sở để kết luận responsiveness của phương án asynchronous từ dữ liệu hiện tại; cần thí nghiệm riêng mô phỏng I/O và heartbeat khi phần đó được triển khai.

## The Isolate Solution

Mỗi isolate có vùng nhớ, biến toàn cục và event loop riêng. Isolate không truy cập trực tiếp trạng thái của nhau mà giao tiếp bằng message. Nhờ đó, công việc ở isolate phụ có thể chạy đồng thời với main isolate trên các lõi CPU sẵn có. [Concurrency in Dart](https://dart.dev/language/concurrency)

Hàm `heavyComputation` được đặt ở top-level và thực hiện 1.500.000.000 vòng lặp để tạo checksum. Trường hợp thứ nhất gọi hàm trực tiếp trên main isolate. Trường hợp thứ hai gọi `await Isolate.run(heavyComputation)`, tạo isolate phụ chạy cùng phép tính rồi trả về kết quả. Trong khi isolate phụ tính, main isolate chỉ chờ Future một cách bất đồng bộ nên event loop vẫn xử lý heartbeat.

`Isolate.run()` phù hợp với một công việc nền đơn lẻ, trả về một kết quả. API tạo isolate, chạy callback, nhận kết quả hoặc lỗi, rồi kết thúc isolate phụ. Callback và kết quả phải là dữ liệu gửi được giữa các isolate. Kết quả của `Isolate.run` có thể được chuyển quyền sở hữu bộ nhớ khi worker kết thúc thay vì sao chép; tuy vậy, tạo isolate và truyền dữ liệu vẫn có chi phí. Với nhiều việc nhỏ lặp lại, có thể dùng isolate sống lâu với `Isolate.spawn()` và port. [Isolates](https://dart.dev/language/isolates), [Isolate.run API](https://api.dart.dev/dart-isolate/Isolate/run.html)

Lần chạy xác minh cho `Isolate.run()` mất `3904 ms`, lâu hơn gọi trực tiếp (`3071 ms`) vì có chi phí tạo worker isolate. Đổi lại, heartbeat tiếp tục từ #3 đến #41 trong khi tính và `maxGapMs` chỉ là `110 ms`. Hai trường hợp cho cùng checksum `1197327744`, nên chúng thực hiện cùng phép tính và cho cùng kết quả.

## Comparison

| Tiêu chí | Synchronous | Isolate |
| --- | --- | --- |
| Mã hiện có | `step2_sync.dart` | `isolate_experiment.dart` |
| Tác vụ được minh họa | Lời gọi tuần tự, chặn main isolate bằng `sleep` | Phép tính CPU-bound với 1.500.000.000 vòng lặp |
| Mô hình thực thi | Cùng main isolate, mã sau lời gọi phải chờ | Worker isolate riêng chạy phép tính; main isolate nhận kết quả qua `Future` |
| Bằng chứng chạy thật | Dòng lệnh sau `downloadFileSync()` xuất hiện sau `4012 ms` | Direct: `3071 ms`, heartbeat gap `3137 ms`; `Isolate.run`: `3904 ms`, max gap `110 ms` |
| Trạng thái main isolate | Bị chặn trong thời gian lời gọi đồng bộ | Vẫn xử lý heartbeat khi worker tính |
| Khả năng phản hồi | Không phản hồi trong thời gian tác vụ chặn | Giữ main isolate phản hồi tốt hơn cho CPU-bound đủ nặng |
| Chi phí | Đơn giản, không có chi phí tạo isolate | Tạo worker, khởi động/JIT và truyền dữ liệu |
| Khi nên dùng | Công việc ngắn, tuần tự, không cần chờ I/O hay tính nặng | CPU-bound đủ nặng để ảnh hưởng trải nghiệm người dùng |

Future/`async`/`await` chưa được đưa vào bảng vì chưa có mã và log thí nghiệm. Khi Step 3 hoàn thành, hàng thứ ba sẽ bổ sung dữ liệu I/O-bound thực tế thay vì số liệu ước đoán.

## Write a brief report explaining

### Why synchronous execution can cause blocking

Thực thi đồng bộ chạy từng câu lệnh theo thứ tự. Lời gọi hiện tại phải kết thúc trước khi main isolate lấy được sự kiện tiếp theo từ event loop. Bởi vậy, nếu lời gọi kéo dài, UI không thể vẽ lại hoặc phản hồi tương tác. Lần chạy `downloadFileSync()` cho thấy mã sau lời gọi chờ `4012 ms`.

### Why asynchronous programming is suitable for I/O-bound operations

Với I/O-bound, thời gian chủ yếu là thời gian chờ hệ điều hành, mạng hoặc máy chủ, chứ không phải CPU tính liên tục. `await` cho phép main isolate nhường thời gian chờ đó cho event loop; khi I/O xong, Future hoàn tất và mã tiếp tục. Cách này giúp chương trình vẫn phản hồi trong khi chờ I/O.

### Why async and await do not automatically solve CPU-intensive computation

`async` không đưa thân hàm sang luồng hay isolate khác. Một vòng lặp CPU nặng không tự nhường quyền điều khiển chỉ vì nó nằm trong hàm `async`; nó vẫn chạy trên main isolate cho đến khi vòng lặp kết thúc hoặc mã gặp một thao tác bất đồng bộ thật sự. Vì vậy heartbeat bị chặn trong trường hợp tính trực tiếp.

### Why Isolates are suitable for CPU-intensive tasks

Isolate đặt phép tính vào event loop và vùng nhớ riêng. Worker có thể chiếm CPU để tính mà không giữ event loop của main isolate. Log cho thấy khi `Isolate.run()` thực hiện phép tính, heartbeat main isolate vẫn tiếp tục xuất hiện với gap gần 100 ms.

### When developers should choose Future async await versus Isolate

Chọn Future/`async`/`await` khi công việc chủ yếu chờ I/O và cần main isolate tiếp tục xử lý sự kiện. Chọn Isolate khi công việc CPU-bound đủ dài để gây rớt khung hình hoặc đơ giao diện, đồng thời dữ liệu gửi nhận và chi phí tạo isolate là chấp nhận được. Với công việc ngắn, tuần tự, thực thi đồng bộ thường đơn giản hơn và không cần thêm cơ chế đồng thời.

## Conclusion hiện tại

Dữ liệu đã có xác nhận hai điểm: lời gọi đồng bộ chặn mã theo sau, và đưa phép tính CPU-bound sang `Isolate.run()` giúp main isolate tiếp tục xử lý heartbeat. Phần Future/`async`/`await` cần được thêm bằng một thí nghiệm I/O-bound riêng trước khi có kết luận thực nghiệm đầy đủ cho cả ba phương án.
