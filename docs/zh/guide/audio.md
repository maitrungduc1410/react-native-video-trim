---
description: "使用 react-native-video-trim 在可缩放的波形上裁剪音频，选择输出格式，并自定义波形条的颜色、宽度、间距和圆角。"
---

# 音频裁剪

<div class="screenshots">
  <img src="../../../images/audio_android.png" alt="Android 编辑器中的音频波形" loading="lazy" />
  <img src="../../../images/audio_ios.png" alt="iOS 编辑器中的音频波形" loading="lazy" />
</div>

设置 `type: 'audio'` 即可裁剪音频文件。编辑器会用波形代替缩略图时间轴，并隐藏视频编辑工具栏。

```ts
showEditor(audioUri, {
  type: 'audio',
  outputExt: 'wav', // 或 'm4a'、'mp3' 等
  maxDuration: 30_000,
});
```

`outputExt` 必须是你所用的 FFmpegKit 构建能够编码的格式。`m4a`（AAC）和 `wav` 在默认构建中即可使用；`mp3` 需要包含 `libmp3lame` 的构建。

## 波形 {#the-waveform}

每个波形条表示一小段音频的 RMS 电平，并经过归一化，最响的一条正好填满轨道高度。用户放大时，会以更高精度重新解码可见范围；缩小时立即恢复完整视图。

对于远程音频文件，波形基于一份只下载一次的本地临时副本绘制，之后每次缩放都复用这份副本。编辑器关闭时会删除该副本。

## 自定义波形 {#customizing-it}

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `waveformColor` | `'white'` | 波形条颜色。 |
| `waveformBackgroundColor` | `'#3478F6'` | 波形条背后的轨道背景色。 |
| `waveformBarWidth` | `3` | 波形条宽度，单位为 dp/pt。 |
| `waveformBarGap` | `2` | 波形条间距，单位为 dp/pt。 |
| `waveformBarCornerRadius` | `1.5` | 波形条圆角半径，单位为 dp/pt。 |

```ts
showEditor(audioUri, {
  type: 'audio',
  outputExt: 'm4a',
  waveformColor: '#1b1b1f',
  waveformBackgroundColor: '#F1D247',
  waveformBarWidth: 2,
  waveformBarGap: 1,
  waveformBarCornerRadius: 1,
});
```

在[主题预览工具](/zh/guide/theming#try-it)中把媒体类型切换为音频，即可预览波形颜色。

## 不用界面裁剪音频 {#headless-audio-trimming}

[`trim()`](/zh/guide/headless#trim) 同样适用于音频：

```ts
const { outputPath } = await trim(audioUri, {
  type: 'audio',
  outputExt: 'm4a',
  startTime: 10_000,
  endTime: 40_000,
});
```

要从视频中提取音频，请使用 [`extractAudio()`](/zh/guide/headless#extractaudio)。
