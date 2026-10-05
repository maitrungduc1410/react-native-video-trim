---
description: "Remove the audio track or change playback speed from 0.25x to 4x, in the react-native-video-trim editor toolbar or with the removeAudio and speed options."
---

# Speed and mute

## Remove the audio

The output can be written without its audio track, from the editor or headlessly.

**In the editor**, the toolbar has a speaker button. Tapping it toggles the audio, and the exported file follows the final state. To always remove the audio, pass `removeAudio`. The editor then opens muted, and the output has no audio even if the user unmutes:

```ts
showEditor(videoUri, { removeAudio: true });
```

**Headless**, pass `removeAudio` to `trim()`, `compress()` or `merge()`:

```ts
const result = await trim(videoUri, {
  startTime: 0,
  endTime: 10_000,
  removeAudio: true,
});
```

## Change the speed

The output speed can range from 0.25x to 4x.

**In the editor**, the toolbar shows the current speed (for example "1x"). Tapping it opens a native menu (`UIMenu` on iOS 14 and later, an action sheet on older iOS, `PopupMenu` on Android) with 0.25x, 0.5x, 1x, 1.5x, 2x, 3x and 4x. The preview plays at the chosen speed and the export uses it. To start at a different speed:

```ts
showEditor(videoUri, { speed: 2.0 });
```

**Headless**, pass `speed` to `trim()`:

```ts
const slowMotion = await trim(videoUri, {
  startTime: 0,
  endTime: 30_000,
  speed: 0.5,
});
```

Any speed other than `1.0` forces a re-encode, regardless of `enablePreciseTrimming`, because changing the tempo needs FFmpeg filters (`setpts` for video, an `atempo` chain for audio). Expect long clips to take longer to process.

## Hiding the toolbar

Both buttons are in the edit toolbar. Set `enableEditTools: false` to hide the whole toolbar; the `removeAudio` and `speed` options you pass still apply.
