# Dọn Ảnh

Ứng dụng iPhone giúp tìm ảnh trùng, video nặng và ảnh chụp màn hình, rồi xoá để giải phóng dung lượng. Mọi thứ xử lý ngay trên máy, không gửi ảnh đi đâu.

Mỗi lần mã được cập nhật, GitHub sẽ tự build lại và đăng tệp **DonAnh.ipa** mới vào mục **Releases** bên phải trang này.

## Cài lên iPhone bằng Windows (không cần Mac)

### Chuẩn bị (chỉ làm một lần)

1. Cài **iTunes** và **iCloud** bản tải từ trang apple.com. Không dùng bản trên Microsoft Store, vì Sideloadly không nhận bản đó.
2. Tải và cài **Sideloadly** tại https://sideloadly.io.
3. Trên iPhone, vào **Cài đặt → Quyền riêng tư & Bảo mật → Chế độ nhà phát triển**, bật lên và khởi động lại máy. Nếu chưa thấy mục này, cứ làm tiếp, nó sẽ xuất hiện sau lần cài đầu tiên.

### Cài app

1. Vào mục **Releases → Dọn Ảnh – bản mới nhất**, tải tệp **DonAnh.ipa** về.
2. Cắm iPhone vào máy tính bằng cáp và bấm **Tin cậy** trên iPhone.
3. Mở Sideloadly, kéo tệp `DonAnh.ipa` vào ô có biểu tượng IPA.
4. Ở ô **Apple account**, nhập Apple ID của bạn rồi bấm **Start**. Nhập mật khẩu và mã xác minh 2 bước nếu được hỏi.
5. Khi Sideloadly báo **Done**, trên iPhone vào **Cài đặt → Cài đặt chung → Quản lý VPN & Thiết bị**, chọn Apple ID của bạn và bấm **Tin cậy**.
6. Mở app **Dọn Ảnh** và chọn **Cho phép truy cập toàn bộ ảnh**.

### Sau 7 ngày

Với Apple ID miễn phí, app hết hạn sau 7 ngày. Khi đó cắm máy và bấm **Start** lại trong Sideloadly, ảnh và dữ liệu của bạn không bị ảnh hưởng. Bạn cũng có thể bật **Auto-refresh** trong Sideloadly để nó tự gia hạn khi iPhone và máy tính dùng chung mạng Wi-Fi.

## Dùng app

- **Ảnh trùng:** ảnh có ngôi sao là bản nét nhất và được giữ. Các bản khác được chọn sẵn để xoá. Chạm vào ảnh để đổi giữa GIỮ và XOÁ. Đổi mức "Y hệt / Rất giống / Hơi giống" để gom chặt hơn hoặc lỏng hơn.
- **Video:** xếp từ nặng nhất xuống. Video gắn nhãn TRÙNG đã được chọn sẵn.
- **Màn hình:** liệt kê toàn bộ ảnh chụp màn hình, có nút "Chọn tất cả".
- Bấm **Xoá** ở thanh dưới, iOS sẽ hỏi xác nhận. Sau đó vào **Ảnh → Album → Đã xoá gần đây → Xoá tất cả** để giải phóng dung lượng ngay.

## Tự build trên Mac (không bắt buộc)

```
brew install xcodegen && xcodegen && open DonAnh.xcodeproj
```
