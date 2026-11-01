# Dọn Ảnh – cài lên iPhone không qua App Store

Ứng dụng làm những việc sau:

- Quét toàn bộ thư viện ảnh và gom các ảnh trùng hoặc gần giống nhau. Bản nét nhất được giữ, các bản còn lại được chọn sẵn để xoá.
- Xếp video từ nặng nhất xuống và tự phát hiện video trùng.
- Liệt kê toàn bộ ảnh chụp màn hình, có nút "Chọn tất cả".
- Xoá các mục đã chọn. iOS sẽ hỏi xác nhận trước khi xoá, và các mục này nằm trong "Đã xoá gần đây" 30 ngày nên vẫn khôi phục được.

Mọi thứ chạy trên iPhone. Ứng dụng không cần mạng và không gửi ảnh đi đâu.

## Bạn cần có

- **Máy Mac** đã cài **Xcode** (tải miễn phí trên Mac App Store). Apple chỉ cho cài ứng dụng tự viết lên iPhone thông qua Xcode trên Mac.
- **Apple ID** của bạn (tài khoản miễn phí là đủ).
- Cáp USB để nối iPhone với Mac.

## Cách 1: dùng XcodeGen (nhanh nhất)

1. Giải nén `DonAnh.zip`.
2. Mở Terminal, chạy:
   ```
   brew install xcodegen
   cd ~/Downloads/DonAnh
   xcodegen
   open DonAnh.xcodeproj
   ```
   Nếu máy chưa có Homebrew, cài tại https://brew.sh hoặc làm theo Cách 2.

## Cách 2: tự tạo dự án trong Xcode

1. Mở Xcode, chọn **File → New → Project → iOS → App**.
2. Đặt Product Name là `DonAnh`, Interface là **SwiftUI**, Language là **Swift**.
3. Xoá hai tệp `ContentView.swift` và `DonAnhApp.swift` mà Xcode tự tạo.
4. Kéo 3 tệp trong thư mục `DonAnh/` (`DonAnhApp.swift`, `PhotoLibrary.swift`, `Views.swift`) vào dự án và tick **Copy items if needed**.
5. Bấm vào target **DonAnh**, mở tab **Info**, bấm dấu **+** và thêm dòng **Privacy - Photo Library Usage Description** với nội dung tuỳ ý, ví dụ "Để tìm và xoá ảnh trùng".
6. Mở tab **Build Settings**, tìm và đặt:
   - **Swift Language Version** = Swift 5
   - **Default Actor Isolation** = nonisolated (chỉ có trên Xcode 26)

## Ký và cài lên iPhone

1. Trong Xcode, vào **Settings → Accounts**, bấm **+** và đăng nhập Apple ID.
2. Bấm target **DonAnh**, mở tab **Signing & Capabilities**, chọn Team là **(Tên bạn) Personal Team**.
   Nếu Xcode báo lỗi Bundle Identifier, đổi `com.thaipham.donanh` thành tên khác, ví dụ `com.thaipham.donanh2`.
3. Cắm iPhone vào Mac và bấm **Tin cậy** trên iPhone.
4. Trên iPhone, vào **Cài đặt → Quyền riêng tư & Bảo mật → Chế độ nhà phát triển**, bật lên và khởi động lại máy.
5. Trong Xcode, chọn iPhone của bạn ở thanh trên cùng, rồi bấm nút **▶ (Run)**.
6. Lần đầu mở app, iPhone sẽ báo "Nhà phát triển không được tin cậy". Vào **Cài đặt → Cài đặt chung → Quản lý VPN & Thiết bị**, chọn Apple ID của bạn và bấm **Tin cậy**.

## Lưu ý

- Với **Apple ID miễn phí**, app chạy được **7 ngày**. Hết hạn thì cắm máy và bấm ▶ lại trong Xcode, ảnh của bạn không bị ảnh hưởng. Tài khoản Apple Developer (99 USD/năm) cho dùng 1 năm.
- Khi app hỏi quyền, hãy chọn **Cho phép truy cập toàn bộ ảnh** để quét được hết thư viện.
- Sau khi xoá trong app, vào **Ảnh → Album → Đã xoá gần đây → Chọn → Xoá tất cả** thì dung lượng mới được giải phóng ngay.
- Nên xem lại từng nhóm trước khi xoá. Ở mức "Hơi giống", app có thể gom nhầm những ảnh chỉ giống bố cục.
- Ảnh chỉ lưu trên iCloud (khi bật "Tối ưu hoá dung lượng") vẫn được so sánh qua ảnh thu nhỏ có sẵn trên máy.
