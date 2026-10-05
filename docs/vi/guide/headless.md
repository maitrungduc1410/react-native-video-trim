---
description: "Xử lý media không cần UI bằng headless API của react-native-video-trim: trim, getFrameAt, extractAudio, compress, toGif, merge, mixAudio và giá trị mặc định."
---

# Headless API

Các hàm này xử lý tệp mà không hiển thị UI nào. Mỗi hàm trả về một Promise, resolve với `outputPath` tuyệt đối của tệp mới. Nếu FFmpeg lỗi, Promise reject với một `Error` có message chứa log FFmpeg.

| Hàm | Chức năng | Mã hóa lại video |
| --- | --- | --- |
| [`trim()`](#trim) | Cắt một đoạn | Chỉ khi cần |
| [`getFrameAt()`](#getframeat) | Lấy một khung hình dưới dạng JPEG hoặc PNG | Không (dùng API của nền tảng) |
| [`extractAudio()`](#extractaudio) | Chỉ giữ lại âm thanh | Không (đầu ra không có video) |
| [`compress()`](#compress) | Giảm dung lượng video | Có |
| [`toGif()`](#togif) | Chuyển một đoạn thành GIF | Có, sang GIF |
| [`merge()`](#merge) | Nối các clip (chỉ tệp cục bộ) | Có |
| [`mixAudio()`](#mixaudio) | Thêm hoặc thay thế track âm thanh (chỉ tệp cục bộ) | Không, stream video được giữ nguyên |

Tùy chọn nào bạn không truyền sẽ nhận giá trị mặc định như bên dưới. Mọi giá trị thời gian đều tính bằng mili giây.

## trim() {#trim}

```ts
trim(url: string, options: Partial<TrimOptions>): Promise<TrimResult>
```

Cắt đoạn từ `startTime` đến `endTime` của một tệp video hoặc âm thanh. Hàm nhận cùng các tùy chọn đầu ra như trình chỉnh sửa: `type`, `outputExt`, `enablePreciseTrimming`, `removeAudio`, `speed` và `saveToPhoto`.

```ts
import { trim } from 'react-native-video-trim';

const { outputPath, startTime, endTime, duration } = await trim(videoUri, {
  startTime: 5_000,
  endTime: 25_000,
});
```

| Tùy chọn | Mặc định | Mô tả |
| --- | --- | --- |
| `startTime` | `0` | Điểm bắt đầu của đoạn. |
| `endTime` | `1000` | Điểm kết thúc của đoạn. Hãy luôn đặt giá trị này. |
| `enablePreciseTrimming` | `false` | Cắt chính xác đến từng khung hình, xem [Cắt chính xác](/vi/guide/precise-trimming). |
| `removeAudio` | `false` | Bỏ track âm thanh. |
| `speed` | `1.0` | Từ 0.25 đến 4. Buộc mã hóa lại khi khác 1. |
| `type` / `outputExt` | `'video'` / `'mp4'` | Loại media và phần mở rộng của đầu ra. |
| `saveToPhoto` | `false` | Đồng thời lưu đầu ra vào thư viện ảnh (trên Android chỉ áp dụng cho video). |

Nếu không bật cắt chính xác hoặc đổi tốc độ, `trim()` dùng stream copy thay vì mã hóa lại. Cách này rất nhanh và không làm giảm chất lượng, nhưng điểm cắt sẽ rơi vào keyframe.

## getFrameAt() {#getframeat}

```ts
getFrameAt(url: string, options?: Partial<FrameExtractionOptions>): Promise<FrameResult>
```

Lấy một khung hình ở độ phân giải đầy đủ bằng API của nền tảng (`AVAssetImageGenerator` trên iOS, `MediaMetadataRetriever` trên Android), rồi thu nhỏ nếu bạn yêu cầu.

```ts
const { outputPath } = await getFrameAt(videoUri, {
  time: 5_000,
  format: 'jpeg',
  quality: 90,
  maxWidth: 640,
});
```

| Tùy chọn | Mặc định | Mô tả |
| --- | --- | --- |
| `time` | `0` | Thời điểm lấy khung hình. |
| `format` | `'jpeg'` | `'jpeg'` hoặc `'png'`. |
| `quality` | `80` | Chất lượng JPEG từ 0 đến 100. Bị bỏ qua với PNG. |
| `maxWidth` | `-1` | Chiều rộng tối đa tính bằng px, giữ nguyên tỷ lệ khung hình. `-1` giữ kích thước gốc. |
| `maxHeight` | `-1` | Chiều cao tối đa tính bằng px, giữ nguyên tỷ lệ khung hình. `-1` giữ kích thước gốc. |

## extractAudio() {#extractaudio}

```ts
extractAudio(url: string, options?: Partial<ExtractAudioOptions>): Promise<ExtractAudioResult>
```

Bỏ stream video và ghi âm thanh ra một tệp riêng. Resolve với `{ outputPath, duration }`.

```ts
const { outputPath, duration } = await extractAudio(videoUri, { outputExt: 'm4a' });
```

| Tùy chọn | Mặc định | Mô tả |
| --- | --- | --- |
| `outputExt` | `'m4a'` | `'m4a'` (AAC) và `'wav'` hoạt động với mọi bản build. `'mp3'` cần bản build FFmpegKit có `libmp3lame`, mà bản build mặc định không có. |

## compress() {#compress}

```ts
compress(url: string, options?: Partial<CompressOptions>): Promise<CompressResult>
```

Mã hóa lại video bằng bộ mã hóa phần cứng H.264 để giảm dung lượng.

```ts
// Preset
const { outputPath } = await compress(videoUri, { quality: 'medium' });

// Thiết lập cụ thể
const { outputPath: small } = await compress(videoUri, {
  width: 720,
  bitrate: 2_000_000,
  frameRate: 30,
  removeAudio: true,
});
```

| Tùy chọn | Mặc định | Mô tả |
| --- | --- | --- |
| `quality` | `'medium'` | `'low'`, `'medium'` hoặc `'high'`. Bị bỏ qua khi đã đặt `bitrate`. Trên Android, các preset nhắm tới 500 kbps, 2 Mbps và 5 Mbps. |
| `bitrate` | `-1` | Bitrate mục tiêu, tính bằng bit/giây. |
| `width` | `-1` | Chiều rộng mục tiêu; chiều cao tính theo tỷ lệ khung hình. |
| `height` | `-1` | Chiều cao mục tiêu; chiều rộng tính theo tỷ lệ khung hình. |
| `frameRate` | `-1` | Frame rate mục tiêu. |
| `outputExt` | `'mp4'` | Phần mở rộng của đầu ra. |
| `removeAudio` | `false` | Bỏ track âm thanh. |

`-1` nghĩa là giữ nguyên giá trị của video gốc.

## toGif() {#togif}

```ts
toGif(url: string, options?: Partial<GifOptions>): Promise<GifResult>
```

Chuyển một đoạn video thành GIF động qua hai lượt (tạo bảng màu rồi áp dụng bảng màu) để màu sắc hiển thị đẹp hơn.

```ts
const { outputPath } = await toGif(videoUri, {
  startTime: 2_000,
  endTime: 7_000,
  fps: 15,
  width: 320,
});
```

| Tùy chọn | Mặc định | Mô tả |
| --- | --- | --- |
| `startTime` | `0` | Điểm bắt đầu của đoạn. |
| `endTime` | `-1` | Điểm kết thúc của đoạn. `-1` nghĩa là đến cuối video. |
| `fps` | `10` | Frame rate của GIF. |
| `width` | `-1` | Chiều rộng tính bằng px; chiều cao tự tính theo tỷ lệ. `-1` giữ kích thước gốc. |

Dung lượng GIF tăng rất nhanh, nên hãy chọn đoạn ngắn và chiều rộng nhỏ.

## merge() {#merge}

```ts
merge(urls: string[], options?: Partial<MergeOptions>): Promise<MergeResult>
```

Nối các clip theo đúng thứ tự truyền vào. Resolve với `{ outputPath, duration }`. Throw đồng bộ nếu `urls` rỗng.

```ts
const { outputPath, duration } = await merge([clip1, clip2, clip3]);
```

| Tùy chọn | Mặc định | Mô tả |
| --- | --- | --- |
| `outputExt` | `'mp4'` | Phần mở rộng của đầu ra. |
| `removeAudio` | `false` | Tạo tệp chỉ có video. |

Cách hoạt động:

- Các clip có thể khác codec, kích thước và frame rate. Mỗi clip được scale và thêm viền đen (letterbox hoặc pillarbox) cho vừa kích thước của clip đầu tiên, rồi chuyển sang frame rate của clip đầu tiên (tối đa 30 fps).
- Bitrate đầu ra bằng bitrate cao nhất trong các đầu vào.
- Clip không có track âm thanh vẫn dùng được. Nếu không clip nào có âm thanh thì đầu ra chỉ có video; ngược lại, phần của mỗi clip không có tiếng sẽ là khoảng lặng dài đúng bằng clip đó.
- Việc ghép luôn mã hóa lại, nên sẽ mất khá lâu nếu clip dài hoặc có nhiều clip.

::: warning Chỉ hỗ trợ tệp cục bộ
`merge()` không nhận URL từ xa, vì bản build FFmpegKit mặc định không kèm OpenSSL. Hãy tải các clip về máy trước.
:::

## mixAudio() {#mixaudio}

```ts
mixAudio(videoPath: string, audioPath: string, options?: Partial<MixAudioOptions>): Promise<MixAudioResult>
```

Trộn thêm một track âm thanh bên ngoài (nhạc nền, lời thuyết minh, ...) vào video, hoặc thay hẳn âm thanh gốc. Stream video được giữ nguyên, chỉ âm thanh được mã hóa lại (sang AAC), nên thao tác này nhanh và không làm giảm chất lượng video.

```ts
// Nhạc nền với âm lượng gốc giảm một nửa, lặp lại suốt toàn bộ video
const { outputPath } = await mixAudio(videoPath, musicPath, {
  originalAudioVolume: 0.5,
  backgroundAudioVolume: 1,
  loopAudio: true,
});

// Thay âm thanh gốc bằng lời thuyết minh bắt đầu sau 2 giây
const { outputPath: dubbed } = await mixAudio(videoPath, voiceOverPath, {
  originalAudioVolume: 0,
  audioStartTime: 2_000,
});
```

| Tùy chọn | Mặc định | Mô tả |
| --- | --- | --- |
| `originalAudioVolume` | `1.0` | Âm lượng của âm thanh gốc trong video. Đặt `0` để thay hẳn âm thanh gốc. |
| `backgroundAudioVolume` | `1.0` | Âm lượng của track được thêm vào. |
| `audioStartTime` | `0` | Độ trễ trước khi track được thêm bắt đầu phát. |
| `loopAudio` | `false` | Lặp lại track được thêm cho đến hết video. |
| `outputExt` | `'mp4'` | Phần mở rộng của đầu ra. |

Đầu ra giữ nguyên độ dài của video. Nếu video không có track âm thanh, track được thêm sẽ là âm thanh duy nhất; khi đó nếu track này ngắn hơn video và `loopAudio` là `false`, đầu ra sẽ kết thúc cùng lúc với track. Giống `merge()`, `mixAudio()` chỉ nhận tệp cục bộ.

## Gọi nối tiếp {#chaining-calls}

Đầu ra là tệp bình thường, nên bạn có thể dùng đầu ra của API này làm đầu vào cho API khác, rồi lưu hoặc chia sẻ kết quả cuối cùng:

```ts
import { compress, deleteFile, saveToPhoto, trim } from 'react-native-video-trim';

const cut = await trim(videoUri, { startTime: 0, endTime: 15_000 });
const small = await compress(cut.outputPath, { quality: 'low' });
await saveToPhoto(small.outputPath);
await Promise.all([deleteFile(cut.outputPath), deleteFile(small.outputPath)]);
```

Tệp đầu ra được ghi ở đâu và cách dọn dẹp có trong [Lưu và quản lý tệp](/vi/guide/files).
