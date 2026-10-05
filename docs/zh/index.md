---
description: "在 React Native 中裁剪视频和音频：提供 iOS 和 Android 原生编辑器，以及裁剪、压缩、合并、转 GIF 和音频处理等 Headless API。"
layout: home

hero:
  name: React Native Video Trim
  text: 原生视频与音频裁剪
  tagline: 为 iOS 和 Android 提供开箱即用的裁剪界面，以及用于裁剪、压缩、合并、混音和生成 GIF 的 Headless API。同时支持新架构和旧架构，也可用于 Expo 开发构建。
  actions:
    - theme: brand
      text: 快速开始
      link: /zh/guide/quick-start
    - theme: alt
      text: 这是什么？
      link: /zh/guide/
    - theme: alt
      text: API 参考
      link: /api/

features:
  - icon: ✂️
    title: 原生裁剪界面
    details: 一行代码即可打开全屏编辑器，内置缩略图时间轴、播放、缩放、触感反馈，以及保存和取消前的确认弹窗。
    link: /zh/guide/editor
    linkText: 打开编辑器
  - icon: 🔄
    title: 翻转、旋转、裁切
    details: 内置编辑工具栏，支持撤销和重做，还提供静音按钮和 0.25x 到 4x 的倍速选择。
    link: /zh/guide/transforms
    linkText: 画面变换
  - icon: 🎵
    title: 带波形的音频裁剪
    details: 在波形上裁剪音频文件，用户放大时会以更高精度重新绘制波形。
    link: /zh/guide/audio
    linkText: 音频裁剪
  - icon: ⚙️
    title: Headless 媒体 API
    details: trim、compress、getFrameAt、extractAudio、toGif、merge 和 mixAudio 不显示任何界面，直接处理文件并返回 Promise。
    link: /zh/guide/headless
    linkText: Headless API
  - icon: 🎨
    title: 深色与浅色主题
    details: 使用浅色主题，并自定义裁剪框、手柄、标题栏和波形的颜色，让编辑器与你的应用风格一致。
    link: /zh/guide/theming
    linkText: 在线调试配色
  - icon: 💾
    title: 保存与分享
    details: 保存到相册、通过文档选择器导出或打开分享面板，既可以在编辑器中完成，也可以用于任意输出文件。
    link: /zh/guide/files
    linkText: 文件与保存
---

<div class="home-section vp-doc">

## 安装 {#install}

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

iOS 还需要运行 `npx pod-install`。权限配置和 Android 选项请参阅[安装](/zh/guide/installation)。

## 一行代码打开编辑器 {#open-the-editor-in-one-call}

```ts
import { showEditor } from 'react-native-video-trim';

showEditor(videoUri, {
  maxDuration: 30_000, // 毫秒
  saveToPhoto: true,
});
```

## 真机效果 {#see-it-on-a-device}

<div class="demo-shots">
  <figure>
    <img src="../../images/ios.gif" alt="在 iOS 上运行的裁剪编辑器" loading="lazy" />
    <figcaption>iOS</figcaption>
  </figure>
  <figure>
    <img src="../../images/android.gif" alt="在 Android 上运行的裁剪编辑器" loading="lazy" />
    <figcaption>Android</figcaption>
  </figure>
</div>

</div>
