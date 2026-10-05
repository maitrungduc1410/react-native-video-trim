---
description: "Chuyển trình chỉnh sửa react-native-video-trim giữa giao diện tối và sáng, thử màu khung cắt, tay kéo, tiêu đề và dạng sóng ngay trong playground."
---

# Theme và màu sắc

Trình chỉnh sửa có sẵn giao diện tối (mặc định) và giao diện sáng, đồng thời cho phép bạn đổi màu một số thành phần cho khớp với màu thương hiệu của ứng dụng.

```ts
showEditor(videoUri, { theme: 'light' });
```

## Thử ngay {#try-it}

Chọn màu bên dưới để xem trước trên bản mô phỏng của trình cắt, rồi sao chép lệnh gọi `showEditor()` tương ứng. Bản xem trước chỉ được vẽ gần đúng bằng CSS; trình chỉnh sửa thật là UI native và có thêm thanh công cụ chỉnh sửa.

<ThemePlayground />

## Theme thay đổi những gì {#what-the-theme-changes}

| | Tối (mặc định) | Sáng |
| --- | --- | --- |
| Nền | Đen | Trắng |
| Biểu tượng và chữ | Trắng | Đen |
| Nhãn Hủy và Lưu | Trắng | Đen |
| Góc khung cắt và lưới | Trắng | Đen |
| Chữ tiêu đề (mặc định của `headerTextColor`) | Trắng | Đen |
| Mũi tên trên tay kéo (mặc định của `handleIconColor`) | Đen | Trắng |
| Hộp thoại | Kiểu tối | Kiểu sáng |

## Tùy chọn màu {#color-options}

Mọi tùy chọn màu đều nhận bất kỳ chuỗi màu React Native nào: `'#f1d247'`, `'#007AFF'`, `'white'`, `'rgb(0, 122, 255)'`. Thư viện chuyển đổi chúng bằng `processColor` trước khi truyền xuống code native.

| Tùy chọn | Mặc định | Tô màu cho |
| --- | --- | --- |
| `trimmerColor` | `'#f1d247'` | Khung cắt và hai tay kéo của nó. |
| `handleIconColor` | đen (tối), trắng (sáng) | Các mũi tên `‹ ›` trên tay kéo. |
| `headerTextColor` | trắng (tối), đen (sáng) | Tiêu đề `headerText`. |
| `waveformColor` | `'white'` | Các thanh dạng sóng, chỉ áp dụng cho âm thanh. |
| `waveformBackgroundColor` | `'#3478F6'` | Nền track phía sau dạng sóng, chỉ áp dụng cho âm thanh. |

`headerTextColor` và `handleIconColor` thay đổi theo theme, trừ khi bạn tự đặt giá trị. Khi đổi `trimmerColor`, hãy kiểm tra xem mũi tên có còn dễ nhìn không; playground có hiển thị tỷ lệ tương phản.

```ts
showEditor(videoUri, {
  theme: 'light',
  headerText: 'Cắt video của bạn',
  headerTextSize: 18,
  trimmerColor: '#007AFF',
  handleIconColor: '#FFFFFF',
});
```

## Văn bản và nhãn {#text-and-labels}

Thư viện không có API đa ngôn ngữ riêng. Mọi nhãn và chuỗi trong hộp thoại đều là tùy chọn, nên bạn chỉ cần truyền chuỗi đã dịch từ lớp i18n của ứng dụng. Danh sách đầy đủ có trong [Mở trình chỉnh sửa](/vi/guide/editor#confirmation-dialogs).

## Nhãn thời gian {#time-labels}

Dùng `durationFormat` để thay đổi cách hiển thị thời gian bắt đầu, hiện tại và kết thúc, ví dụ `'mm:ss'` để ẩn phần mili giây. Xem [Định dạng nhãn thời gian](/vi/guide/editor#time-label-format).
