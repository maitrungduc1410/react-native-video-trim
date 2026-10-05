---
description: "react-native-video-trim 中 showEditor() 的全部选项：时长限制、播放、保存与分享、按钮文字、时间格式和确认弹窗。"
---

# 打开编辑器

```ts
showEditor(filePath: string, config: EditorOptions): void
```

[`showEditor()`](/api/functions/showEditor) 会全屏打开原生裁剪界面。`filePath` 可以是本地路径或 `file://` URI；安装了 [`https` FFmpegKit 包](/zh/guide/remote-files)后，也可以是 HTTPS URL。所有选项都是可选的，但请始终传入一个对象（`{}` 即可）。

```ts
import { showEditor } from 'react-native-video-trim';

showEditor(videoUri, {
  maxDuration: 60_000,
  minDuration: 3_000,
  autoplay: true,
  saveToPhoto: true,
  openShareSheetOnFinish: true,
  headerText: '裁剪你的视频',
});
```

该函数会立即返回，后续进展通过[事件](/zh/guide/events)通知：`onShow`、`onLoad`、`onStartTrimming`、`onFinishTrimming`、`onCancel`、`onHide` 等。如需在代码中关闭编辑器，调用 [`closeEditor()`](/api/functions/closeEditor)。

选项的类型为 [`EditorOptions`](/api/type-aliases/EditorOptions)。下面按用途分组列出最常用的选项；全部字段请查看 [`EditorConfig`](/api/interfaces/EditorConfig) 的 API 参考。

## 媒体与输出 {#media-and-output}

| 选项 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `type` | `'video' \| 'audio'` | `'video'` | 媒体类型。`'audio'` 会显示[波形](/zh/guide/audio)。 |
| `outputExt` | `string` | `'mp4'` | 输出文件扩展名，例如 `'mov'`、`'wav'`、`'m4a'`。 |
| `maxDuration` | `number` | `-1`（不限制） | 可选范围的最长时长，单位为毫秒。 |
| `minDuration` | `number` | `-1` | 可选范围的最短时长，单位为毫秒。无论如何设置，编辑器都不允许短于 1 秒。 |
| `enablePreciseTrimming` | `boolean` | `false` | 重新编码以实现帧级精确裁剪。参阅[精确裁剪](/zh/guide/precise-trimming)。 |
| `removeAudio` | `boolean` | `false` | 输出中去除音频。编辑器打开时即为静音状态，即使用户取消静音，输出仍然没有声音。参阅[倍速与静音](/zh/guide/speed-and-mute)。 |
| `speed` | `number` | `1.0` | 初始倍速，范围为 0.25 到 4。 |

## 播放 {#playback}

| 选项 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `autoplay` | `boolean` | `false` | 媒体加载完成后自动开始播放。 |
| `jumpToPositionOnLoad` | `number` | `-1` | 加载完成后跳转到该位置（毫秒）。 |
| `zoomOnWaitingDuration` | `number` | `5000` | 用户按住手柄不动时，时间轴会放大到手柄附近这段时长（毫秒），便于微调。 |
| `enableHapticFeedback` | `boolean` | `true` | 拖动手柄以及手柄到达两端时提供触感反馈。 |
| `enableEditTools` | `boolean` | `true` | 显示工具栏（翻转、旋转、裁切、静音、倍速、撤销、重做）。仅适用于视频。 |

## 用户保存时 {#when-the-user-saves}

| 选项 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `saveToPhoto` | `boolean` | `false` | 将输出保存到相册。需要[相册权限](/zh/guide/installation#ios)。 |
| `openDocumentsOnFinish` | `boolean` | `false` | 打开系统文档选择器，让用户保存输出文件。 |
| `openShareSheetOnFinish` | `boolean` | `false` | 打开分享面板分享输出文件。 |
| `closeWhenFinish` | `boolean` | `true` | 裁剪成功后关闭编辑器。 |
| `removeAfterSavedToPhoto` | `boolean` | `false` | 保存到相册后删除输出文件。 |
| `removeAfterFailedToSavePhoto` | `boolean` | `false` | 保存到相册失败时删除输出文件。 |
| `removeAfterSavedToDocuments` | `boolean` | `false` | 通过文档选择器保存后删除输出文件。 |
| `removeAfterFailedToSaveDocuments` | `boolean` | `false` | 通过文档选择器保存失败时删除输出文件。 |
| `removeAfterShared` | `boolean` | `false` | 分享后删除输出文件（仅 iOS）。 |
| `removeAfterFailedToShare` | `boolean` | `false` | 分享失败时删除输出文件（仅 iOS）。 |

## 外观与文字 {#text-and-appearance}

| 选项 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `theme` | `'dark' \| 'light'` | `'dark'` | 编辑器主题。参阅[主题](/zh/guide/theming)。 |
| `headerText` | `string` | `''` | 编辑器顶部的标题。 |
| `headerTextSize` | `number` | `16` | 标题字号，单位为 sp/pt。 |
| `headerTextColor` | 颜色字符串 | 取决于主题 | 标题颜色。 |
| `trimmerColor` | 颜色字符串 | `'#f1d247'` | 裁剪框及手柄的颜色。 |
| `handleIconColor` | 颜色字符串 | 取决于主题 | 手柄上箭头图标的颜色。 |
| `cancelButtonText` | `string` | `'Cancel'` | 取消按钮文字。 |
| `saveButtonText` | `string` | `'Save'` | 保存按钮文字。 |
| `trimmingText` | `string` | `'Trimming video...'` | 进度弹窗中的文字。 |
| `durationFormat` | `string` | `'mm:ss.SSS'` | 时间标签的格式，见下文。 |
| `fullScreenModalIOS` | `boolean` | `false` | iOS：以全屏模态（而不是卡片式弹层）展示。 |
| `changeStatusBarColorOnOpen` | `boolean` | `false` | Android：编辑器打开期间将状态栏设为黑色。 |

### 时间标签格式 {#time-label-format}

`durationFormat` 控制开始、当前和结束时间标签的显示格式。它不影响事件数据，事件中的时间始终是毫秒数值。

| 取值 | 示例 |
| --- | --- |
| `'mm:ss'` | `01:23` |
| `'mm:ss.SS'` | `01:23.45` |
| `'mm:ss.SSS'`（默认） | `01:23.456` |
| `'hh:mm:ss'` | `00:01:23` |
| `'hh:mm:ss.SSS'` | `00:01:23.456` |

无法识别的取值会回退到默认格式。

## 确认弹窗 {#confirmation-dialogs}

每个弹窗都可以关闭或修改文案，编辑器的多语言适配也是通过这些选项完成的。

| 弹窗 | 开关选项 | 文案选项 |
| --- | --- | --- |
| 取消编辑 | `enableCancelDialog`（`true`） | `cancelDialogTitle`、`cancelDialogMessage`、`cancelDialogCancelText`、`cancelDialogConfirmText` |
| 保存 | `enableSaveDialog`（`true`） | `saveDialogTitle`、`saveDialogMessage`、`saveDialogCancelText`、`saveDialogConfirmText` |
| 取消正在进行的裁剪 | `enableCancelTrimmingDialog`（`true`） | `cancelTrimmingDialogTitle`、`cancelTrimmingDialogMessage`、`cancelTrimmingDialogCancelText`、`cancelTrimmingDialogConfirmText` |
| 媒体加载失败 | `alertOnFailToLoad`（`true`） | `alertOnFailTitle`、`alertOnFailMessage`、`alertOnFailCloseText` |

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

## 进度与取消 {#progress-and-cancelling}

<div class="screenshots">
  <img src="../../../images/progress.jpg" alt="裁剪过程中的进度弹窗" loading="lazy" />
  <img src="../../../images/cancel_confirm.jpg" alt="取消裁剪前的确认弹窗" loading="lazy" />
</div>

处理文件期间，编辑器会显示进度弹窗，文字为 `trimmingText`。当 `enableCancelTrimming` 为 `true`（默认值）时，用户可以中止裁剪，此时编辑器会发出 `onCancelTrimming` 事件。

```ts
showEditor(videoUri, {
  trimmingText: '正在处理视频...',
  enableCancelTrimming: true,
  cancelTrimmingButtonText: '停止',
  enableCancelTrimmingDialog: true,
});
```

如果想在其他地方显示自定义进度，可以监听 `onStatistics`，它提供 FFmpeg 的处理进度（`time`，单位为毫秒）和处理速度。参阅[事件](/zh/guide/events#progress)。

## 完整配置示例 {#a-complete-configuration}

```ts
showEditor(videoUri, {
  // 范围
  maxDuration: 60_000,
  minDuration: 3_000,

  // 输出
  saveToPhoto: true,
  removeAfterSavedToPhoto: true,
  openShareSheetOnFinish: true,

  // 音频与倍速
  removeAudio: false,
  speed: 1.0,

  // 外观
  theme: 'light',
  headerText: '裁剪你的视频',
  cancelButtonText: '返回',
  saveButtonText: '完成',
  trimmerColor: '#007AFF',

  // 行为
  autoplay: true,
  enableCancelTrimming: true,
});
```
