---
description: "react-native-video-trim ghi tệp đầu ra ở đâu, cách lưu chúng vào thư viện ảnh hoặc qua trình chọn tài liệu, chia sẻ, liệt kê, kiểm tra và xóa tệp."
---

# Lưu và quản lý tệp

<div class="screenshots">
  <img src="../../../images/document_picker.png" alt="Lưu qua trình chọn tài liệu của hệ thống" loading="lazy" />
  <img src="../../../images/share_sheet.png" alt="Chia sẻ tệp đầu ra qua bảng chia sẻ" loading="lazy" />
</div>

## Tệp được ghi ở đâu {#where-files-are-written}

| Tạo bởi | Thư mục | Vòng đời |
| --- | --- | --- |
| `showEditor()`, `trim()` | Thư mục Documents của ứng dụng (iOS) / `filesDir` (Android) | Được giữ lại cho đến khi bạn xóa. |
| `getFrameAt()`, `extractAudio()`, `compress()`, `toGif()`, `merge()`, `mixAudio()` | Caches (iOS) / `cacheDir` (Android) | Hệ điều hành có thể tự xóa khi bộ nhớ sắp đầy và ứng dụng không chạy. |

Dù tệp được tạo từ đâu, hãy xóa khi dùng xong. Tệp nào muốn giữ lại thì chuyển sang chỗ lưu trữ lâu dài, hoặc lưu bằng một trong các hàm dưới đây.

## Lưu và chia sẻ {#saving-and-sharing}

Các hàm này dùng được với đầu ra của mọi API.

### Lưu vào thư viện ảnh {#save-to-photos}

```ts
saveToPhoto(filePath: string): Promise<SaveToPhotoResult>
```

Lưu ảnh hoặc video vào thư viện ảnh. Loại tệp được nhận diện theo phần mở rộng, nên các khung hình từ `getFrameAt()` sẽ được lưu dưới dạng ảnh. Cần [quyền truy cập thư viện ảnh](/vi/guide/installation#ios) trên iOS, và quyền bộ nhớ trên Android 9 trở xuống.

```ts
import { compress, saveToPhoto } from 'react-native-video-trim';

const { outputPath } = await compress(videoUri, { quality: 'medium' });
const { success } = await saveToPhoto(outputPath);
```

### Lưu qua trình chọn tài liệu {#save-to-documents}

```ts
saveToDocuments(filePath: string): Promise<SaveToDocumentsResult>
```

Mở trình chọn tài liệu của hệ thống (`UIDocumentPickerViewController` trên iOS, Storage Access Framework trên Android) để người dùng chọn nơi lưu tệp.

### Chia sẻ {#share}

```ts
share(filePath: string): Promise<ShareResult>
```

Mở bảng chia sẻ. Trên Android, tệp phải nằm trong thư mục đầu ra của thư viện; mọi tệp đầu ra của thư viện đều đã nằm ở đó.

```ts
const { outputPath } = await merge([clip1, clip2]);
const { success } = await share(outputPath);
```

Trình chỉnh sửa cũng làm được những việc này ngay sau khi lưu, qua `saveToPhoto`, `openDocumentsOnFinish` và `openShareSheetOnFinish`, rồi xóa tệp bằng các tùy chọn `removeAfter*`. Xem [Khi người dùng lưu](/vi/guide/editor#when-the-user-saves).

Cả ba hàm đều throw đồng bộ khi `filePath` rỗng.

## Quản lý đầu ra {#managing-outputs}

| Hàm | Trả về | Mô tả |
| --- | --- | --- |
| [`listFiles()`](/api/functions/listFiles) | `Promise<string[]>` | Mọi tệp đầu ra trong cả hai thư mục. |
| [`cleanFiles()`](/api/functions/cleanFiles) | `Promise<number>` | Xóa mọi tệp đầu ra, trả về số tệp đã xóa. |
| [`deleteFile(path)`](/api/functions/deleteFile) | `Promise<boolean>` | Xóa một tệp đầu ra. Trên Android, đường dẫn nằm ngoài thư mục đầu ra sẽ bị từ chối và Promise resolve với `false`. |
| [`isValidFile(url)`](/api/functions/isValidFile) | `Promise<FileValidationResult>` | Kiểm tra một tệp có phải là âm thanh hoặc video phát được hay không. |

```ts
import { cleanFiles, deleteFile, isValidFile, listFiles } from 'react-native-video-trim';

// Kiểm tra trước khi mở trình chỉnh sửa
const { isValid, fileType, duration } = await isValidFile(uri);
if (!isValid) {
  console.warn('Not a playable media file');
}

// Xóa một tệp
await deleteFile(outputPath);

// Dọn dẹp định kỳ, ví dụ khi ứng dụng khởi động
const files = await listFiles();
const removed = await cleanFiles();
console.log(`Removed ${removed} of ${files.length} files`);
```

`isValidFile()` resolve với một object, không phải boolean. Hãy kiểm tra `isValid`; `fileType` là `'video'`, `'audio'` hoặc `'unknown'`, còn `duration` tính bằng mili giây (`-1` khi không hợp lệ).
