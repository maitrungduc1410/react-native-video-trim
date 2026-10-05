---
description: "Toàn bộ tùy chọn của showEditor() trong react-native-video-trim: giới hạn thời lượng, phát lại, lưu và chia sẻ, nhãn, định dạng thời gian và hộp thoại xác nhận."
---

# Mở trình chỉnh sửa

```ts
showEditor(filePath: string, config: EditorOptions): void
```

[`showEditor()`](/api/functions/showEditor) hiển thị trình cắt native ở chế độ toàn màn hình. `filePath` có thể là đường dẫn cục bộ, URI `file://`, hoặc URL HTTPS nếu bạn đã cài [package FFmpegKit `https`](/vi/guide/remote-files). Mọi tùy chọn đều không bắt buộc, nhưng bạn vẫn phải truyền một object (`{}` cũng được).

```ts
import { showEditor } from 'react-native-video-trim';

showEditor(videoUri, {
  maxDuration: 60_000,
  minDuration: 3_000,
  autoplay: true,
  saveToPhoto: true,
  openShareSheetOnFinish: true,
  headerText: 'Cắt video của bạn',
});
```

Hàm trả về ngay. Những gì diễn ra sau đó được báo lại qua các [sự kiện](/vi/guide/events): `onShow`, `onLoad`, `onStartTrimming`, `onFinishTrimming`, `onCancel`, `onHide`, v.v. Gọi [`closeEditor()`](/api/functions/closeEditor) để đóng trình chỉnh sửa từ code.

Kiểu của các tùy chọn là [`EditorOptions`](/api/type-aliases/EditorOptions). Các bảng dưới đây gom nhóm những tùy chọn hay dùng nhất; trang tài liệu API của [`EditorConfig`](/api/interfaces/EditorConfig) liệt kê đầy đủ mọi trường.

## Media và đầu ra {#media-and-output}

| Tùy chọn | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `type` | `'video' \| 'audio'` | `'video'` | Loại media. `'audio'` hiển thị [dạng sóng](/vi/guide/audio). |
| `outputExt` | `string` | `'mp4'` | Phần mở rộng của tệp đầu ra, ví dụ `'mov'`, `'wav'`, `'m4a'`. |
| `maxDuration` | `number` | `-1` (không giới hạn) | Độ dài tối đa của đoạn được chọn, tính bằng ms. |
| `minDuration` | `number` | `-1` | Độ dài tối thiểu của đoạn được chọn, tính bằng ms. Dù đặt thế nào, trình chỉnh sửa cũng không cho chọn đoạn ngắn hơn 1 giây. |
| `enablePreciseTrimming` | `boolean` | `false` | Mã hóa lại để cắt chính xác đến từng khung hình. Xem [Cắt chính xác](/vi/guide/precise-trimming). |
| `removeAudio` | `boolean` | `false` | Bỏ âm thanh khỏi tệp đầu ra. Trình chỉnh sửa mở ở trạng thái tắt tiếng, và đầu ra vẫn không có tiếng dù người dùng bật lại âm thanh. Xem [Tốc độ và tắt tiếng](/vi/guide/speed-and-mute). |
| `speed` | `number` | `1.0` | Tốc độ ban đầu, từ 0.25 đến 4. |

## Phát lại {#playback}

| Tùy chọn | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `autoplay` | `boolean` | `false` | Tự động phát khi media đã tải xong. |
| `jumpToPositionOnLoad` | `number` | `-1` | Tua đến vị trí này (ms) sau khi tải xong. |
| `zoomOnWaitingDuration` | `number` | `5000` | Khi người dùng giữ yên tay kéo, dòng thời gian phóng to để chỉ hiển thị khoảng thời gian này (ms) quanh tay kéo, giúp chỉnh chính xác hơn. |
| `enableHapticFeedback` | `boolean` | `true` | Rung phản hồi khi kéo tay kéo và khi chạm hai đầu dòng thời gian. |
| `enableEditTools` | `boolean` | `true` | Hiển thị thanh công cụ (lật, xoay, cắt khung, tắt tiếng, tốc độ, hoàn tác, làm lại). Chỉ áp dụng cho video. |

## Khi người dùng lưu {#when-the-user-saves}

| Tùy chọn | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `saveToPhoto` | `boolean` | `false` | Lưu đầu ra vào thư viện ảnh. Cần [quyền truy cập](/vi/guide/installation#ios). |
| `openDocumentsOnFinish` | `boolean` | `false` | Mở trình chọn tài liệu của hệ thống để người dùng lưu tệp đầu ra. |
| `openShareSheetOnFinish` | `boolean` | `false` | Mở bảng chia sẻ với tệp đầu ra. |
| `closeWhenFinish` | `boolean` | `true` | Đóng trình chỉnh sửa sau khi cắt thành công. |
| `removeAfterSavedToPhoto` | `boolean` | `false` | Xóa tệp đầu ra sau khi đã lưu vào thư viện ảnh. |
| `removeAfterFailedToSavePhoto` | `boolean` | `false` | Xóa tệp đầu ra nếu lưu vào thư viện ảnh thất bại. |
| `removeAfterSavedToDocuments` | `boolean` | `false` | Xóa tệp đầu ra sau khi đã lưu qua trình chọn tài liệu. |
| `removeAfterFailedToSaveDocuments` | `boolean` | `false` | Xóa tệp đầu ra nếu lưu qua trình chọn tài liệu thất bại. |
| `removeAfterShared` | `boolean` | `false` | Xóa tệp đầu ra sau khi chia sẻ (chỉ iOS). |
| `removeAfterFailedToShare` | `boolean` | `false` | Xóa tệp đầu ra nếu chia sẻ thất bại (chỉ iOS). |

## Văn bản và giao diện {#text-and-appearance}

| Tùy chọn | Kiểu | Mặc định | Mô tả |
| --- | --- | --- | --- |
| `theme` | `'dark' \| 'light'` | `'dark'` | Theme của trình chỉnh sửa. Xem [Theme và màu sắc](/vi/guide/theming). |
| `headerText` | `string` | `''` | Tiêu đề ở đầu trình chỉnh sửa. |
| `headerTextSize` | `number` | `16` | Cỡ chữ tiêu đề, tính bằng sp/pt. |
| `headerTextColor` | chuỗi màu | theo theme | Màu tiêu đề. |
| `trimmerColor` | chuỗi màu | `'#f1d247'` | Màu của khung cắt và các tay kéo. |
| `handleIconColor` | chuỗi màu | theo theme | Màu của các mũi tên trên tay kéo. |
| `cancelButtonText` | `string` | `'Cancel'` | Nhãn nút Hủy. |
| `saveButtonText` | `string` | `'Save'` | Nhãn nút Lưu. |
| `trimmingText` | `string` | `'Trimming video...'` | Văn bản trong hộp thoại tiến trình. |
| `durationFormat` | `string` | `'mm:ss.SSS'` | Định dạng của nhãn thời gian, xem bên dưới. |
| `fullScreenModalIOS` | `boolean` | `false` | iOS: hiển thị dạng modal toàn màn hình thay vì sheet. |
| `changeStatusBarColorOnOpen` | `boolean` | `false` | Android: chuyển thanh trạng thái sang màu đen khi trình chỉnh sửa đang mở. |

### Định dạng nhãn thời gian {#time-label-format}

`durationFormat` quyết định cách hiển thị các nhãn thời gian bắt đầu, hiện tại và kết thúc. Tùy chọn này không ảnh hưởng đến payload của sự kiện: payload luôn là số mili giây nguyên gốc.

| Giá trị | Ví dụ |
| --- | --- |
| `'mm:ss'` | `01:23` |
| `'mm:ss.SS'` | `01:23.45` |
| `'mm:ss.SSS'` (mặc định) | `01:23.456` |
| `'hh:mm:ss'` | `00:01:23` |
| `'hh:mm:ss.SSS'` | `00:01:23.456` |

Giá trị không hợp lệ sẽ được thay bằng giá trị mặc định.

## Hộp thoại xác nhận {#confirmation-dialogs}

Mọi hộp thoại đều có thể tắt đi hoặc đổi nội dung. Đây cũng là cách để bạn dịch trình chỉnh sửa sang ngôn ngữ khác.

| Hộp thoại | Bật/tắt bằng | Tùy chọn nội dung |
| --- | --- | --- |
| Thoát trình chỉnh sửa | `enableCancelDialog` (`true`) | `cancelDialogTitle`, `cancelDialogMessage`, `cancelDialogCancelText`, `cancelDialogConfirmText` |
| Lưu | `enableSaveDialog` (`true`) | `saveDialogTitle`, `saveDialogMessage`, `saveDialogCancelText`, `saveDialogConfirmText` |
| Hủy thao tác cắt đang chạy | `enableCancelTrimmingDialog` (`true`) | `cancelTrimmingDialogTitle`, `cancelTrimmingDialogMessage`, `cancelTrimmingDialogCancelText`, `cancelTrimmingDialogConfirmText` |
| Không tải được media | `alertOnFailToLoad` (`true`) | `alertOnFailTitle`, `alertOnFailMessage`, `alertOnFailCloseText` |

```ts
showEditor(videoUri, {
  cancelButtonText: 'Quay lại',
  saveButtonText: 'Xong',
  saveDialogTitle: 'Lưu video?',
  saveDialogMessage: 'Đoạn video đã chọn sẽ được lưu.',
  saveDialogCancelText: 'Không',
  saveDialogConfirmText: 'Lưu',
});
```

## Tiến trình và hủy {#progress-and-cancelling}

<div class="screenshots">
  <img src="../../../images/progress.jpg" alt="Hộp thoại tiến trình khi đang cắt" loading="lazy" />
  <img src="../../../images/cancel_confirm.jpg" alt="Xác nhận trước khi hủy thao tác cắt" loading="lazy" />
</div>

Trong lúc xử lý tệp, trình chỉnh sửa hiển thị hộp thoại tiến trình với nội dung `trimmingText`. Khi `enableCancelTrimming` là `true` (mặc định), người dùng có thể dừng giữa chừng; lúc đó trình chỉnh sửa phát sự kiện `onCancelTrimming`.

```ts
showEditor(videoUri, {
  trimmingText: 'Đang xử lý video...',
  enableCancelTrimming: true,
  cancelTrimmingButtonText: 'Dừng',
  enableCancelTrimmingDialog: true,
});
```

Nếu muốn tự hiển thị UI tiến trình ở chỗ khác, hãy lắng nghe `onStatistics`. Sự kiện này cho biết FFmpeg đã xử lý đến vị trí nào (`time`, tính bằng ms) và với tốc độ bao nhiêu. Xem [Sự kiện](/vi/guide/events#progress).

## Ví dụ cấu hình đầy đủ {#a-complete-configuration}

```ts
showEditor(videoUri, {
  // khoảng cắt
  maxDuration: 60_000,
  minDuration: 3_000,

  // đầu ra
  saveToPhoto: true,
  removeAfterSavedToPhoto: true,
  openShareSheetOnFinish: true,

  // âm thanh và tốc độ
  removeAudio: false,
  speed: 1.0,

  // giao diện
  theme: 'light',
  headerText: 'Cắt video của bạn',
  cancelButtonText: 'Quay lại',
  saveButtonText: 'Xong',
  trimmerColor: '#007AFF',

  // hành vi
  autoplay: true,
  enableCancelTrimming: true,
});
```
