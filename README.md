# PRM392

## Step 2: Thí nghiệm thực thi đồng bộ

Chạy ví dụ bằng Dart SDK:

```sh
dart run step2_sync.dart
```

`downloadFileSync()` dùng `sleep` để **mô phỏng** một tác vụ kéo dài 4 giây. Hàm không tải tệp thật. Lệnh `print` ngay sau lời gọi hàm trong `main()` sẽ chỉ xuất hiện khi tác vụ kết thúc, với thời gian đo được khoảng 4.000 ms.

Kết quả dự kiến:

```text
Bat dau tac vu dong bo (mo phong tai tep trong 4 giay)...
Tac vu dong bo da hoan thanh.
Lenh ngay sau downloadFileSync(): 4000 ms
```

Con số mili giây thực tế có thể lệch nhẹ tùy máy. Trong ứng dụng Flutter, nếu một tác vụ chặn tương tự chạy trên main isolate, isolate đó không thể xử lý vẽ khung hình và tương tác trong lúc chờ. Giao diện sẽ bị đứng trong khoảng thời gian đó.

## Step 3: Phương pháp đề xuất & Thí nghiệm #2 (Hiện đại - Bất đồng bộ)

Refactor hàm ở Step 2 thành `Future<void> downloadFileAsync()` dùng `Future`, `async` và `await`. Hàm mô phỏng một tác vụ I/O-bound (ví dụ: gọi mạng, thao tác database, tải tệp) bằng `Future.delayed()` để giả lập thời gian chờ.

Chạy ví dụ:

```sh
dart run step3_async.dart
```

Kết quả thực tế khi chạy:

```text
Bat dau tac vu bat dong bo (mo phong tai tep qua mang trong 4 giay)...
Lenh ngay sau downloadFileAsync(): 4 ms (chay ngay, khong doi tac vu bat dong bo)
Tac vu bat dong bo da hoan thanh.
Toan bo chuong trinh hoan tat sau: 4014 ms
```

### Quan sát

Khác với `downloadFileSync()` ở Step 2 (chặn hoàn toàn trong 4000ms), khi gọi `downloadFileAsync()` **mà không `await` ngay**, hàm trả về một `Future` và trả quyền điều khiển lại cho `main()` ngay lập tức. Vì vậy lệnh `print` kế tiếp trong `main()` được thực thi gần như tức thì (~4ms) — **trước khi** tác vụ bất đồng bộ hoàn tất, thay vì phải đợi đủ 4 giây như ở Step 2. Chỉ đến khi chương trình `await future`, nó mới tạm dừng để chờ kết quả, và toàn bộ tiến trình kết thúc sau khoảng 4014ms.

### Future, async, await cải thiện khả năng phản hồi (responsiveness) như thế nào?

- **Không chặn main isolate**: `await` chỉ tạm dừng *hàm hiện tại* (coroutine), không dừng toàn bộ isolate. Trong lúc chờ tác vụ I/O-bound hoàn thành (mạng, DB, tệp), main isolate vẫn rảnh để xử lý các sự kiện khác — vẽ khung hình (frame), xử lý input người dùng, chạy các tác vụ khác.
- **UI không bị đứng**: Trong Flutter, vì main isolate không bị chặn, giao diện vẫn mượt (không bị "janky"/đứng khung hình) trong khi chờ dữ liệu tải về, khác hẳn với việc dùng `sleep()` đồng bộ như ở Step 2.
- **Mô hình lập trình rõ ràng, dễ đọc**: `async`/`await` cho phép viết code bất đồng bộ theo phong cách tuần tự (thay vì callback lồng nhau), giúp dễ đọc, dễ maintain mà vẫn giữ được tính không chặn (non-blocking).
- **Tận dụng thời gian chờ I/O**: Trong lúc một `Future` (ví dụ request mạng) đang chờ kết quả từ bên ngoài, CPU không bị "lãng phí" đứng chờ — event loop có thể xử lý các tác vụ khác, cải thiện thông lượng (throughput) và trải nghiệm người dùng tổng thể.
