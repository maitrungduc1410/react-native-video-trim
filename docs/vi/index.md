---
description: "Cắt video và âm thanh trong React Native với trình chỉnh sửa native dựng sẵn cho iOS và Android, kèm headless API để cắt, nén, ghép, tạo GIF và xử lý âm thanh."
layout: home

hero:
  name: React Native Video Trim
  text: Cắt video và âm thanh, xử lý hoàn toàn native
  tagline: Màn hình cắt dựng sẵn cho iOS và Android, kèm các headless API để cắt, nén, ghép video, trộn âm thanh và tạo GIF. Chạy được trên cả New Architecture lẫn Old Architecture, và trong development build của Expo.
  actions:
    - theme: brand
      text: Bắt đầu
      link: /vi/guide/quick-start
    - theme: alt
      text: Đây là gì?
      link: /vi/guide/
    - theme: alt
      text: Tài liệu API
      link: /api/

features:
  - icon: ✂️
    title: UI cắt video native
    details: Chỉ cần một lệnh gọi để mở trình chỉnh sửa toàn màn hình, có dòng thời gian thumbnail, thu phóng, rung phản hồi, phát lại và hộp thoại xác nhận lưu hoặc hủy.
    link: /vi/guide/editor
    linkText: Mở trình chỉnh sửa
  - icon: 🔄
    title: Lật, xoay, cắt khung
    details: Thanh công cụ chỉnh sửa dựng sẵn, có hoàn tác và làm lại, cùng nút tắt tiếng và bộ chọn tốc độ từ 0.25x đến 4x.
    link: /vi/guide/transforms
    linkText: Biến đổi hình ảnh
  - icon: 🎵
    title: Cắt âm thanh trên dạng sóng
    details: Cắt tệp âm thanh ngay trên dạng sóng. Khi người dùng phóng to, dạng sóng được vẽ lại ở độ phân giải cao hơn.
    link: /vi/guide/audio
    linkText: Cắt âm thanh
  - icon: ⚙️
    title: Headless API xử lý media
    details: trim, compress, getFrameAt, extractAudio, toGif, merge và mixAudio chạy mà không cần UI và trả về Promise.
    link: /vi/guide/headless
    linkText: Headless API
  - icon: 🎨
    title: Giao diện tối và sáng
    details: Phối màu theo ứng dụng của bạn với giao diện sáng và màu tùy chỉnh cho khung cắt, tay kéo, tiêu đề và dạng sóng.
    link: /vi/guide/theming
    linkText: Thử playground
  - icon: 💾
    title: Lưu và chia sẻ
    details: Lưu vào thư viện ảnh, xuất qua trình chọn tài liệu hoặc mở bảng chia sẻ, ngay từ trình chỉnh sửa hoặc với bất kỳ tệp đầu ra nào.
    link: /vi/guide/files
    linkText: Lưu và quản lý tệp
---

<div class="home-section vp-doc">

## Cài đặt {#install}

::: code-group

```sh [npm]
npm install react-native-video-trim
```

```sh [yarn]
yarn add react-native-video-trim
```

```sh [Expo]
npx expo install react-native-video-trim
npx expo prebuild
```

:::

Sau đó chạy `npx pod-install` cho iOS. Xem [Cài đặt](/vi/guide/installation) để biết cách cấp quyền và các tùy chọn cho Android.

## Mở trình chỉnh sửa chỉ với một lệnh gọi {#open-the-editor-in-one-call}

```ts
import { showEditor } from 'react-native-video-trim';

showEditor(videoUri, {
  maxDuration: 30_000, // mili giây
  saveToPhoto: true,
});
```

## Xem trên thiết bị thật {#see-it-on-a-device}

<div class="demo-shots">
  <figure>
    <img src="../../images/ios.gif" alt="Trình chỉnh sửa cắt video chạy trên iOS" loading="lazy" />
    <figcaption>iOS</figcaption>
  </figure>
  <figure>
    <img src="../../images/android.gif" alt="Trình chỉnh sửa cắt video chạy trên Android" loading="lazy" />
    <figcaption>Android</figcaption>
  </figure>
</div>

</div>
