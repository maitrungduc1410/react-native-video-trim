---
description: "Flip, rotate and freely crop videos with undo and redo in the react-native-video-trim editor, and what happens when the result is exported."
---

# Flip, rotate, crop

The editor toolbar has transform tools on both iOS and Android:

- **Flip** horizontally.
- **Rotate** 90° counterclockwise.
- **Crop** freely with an overlay that has corner brackets and a grid, and that the user can drag and pinch.
- **Undo** and **redo** for every step.

There is nothing to configure. The tools appear for videos (never for audio) as long as `enableEditTools` is `true`, which is the default.

```ts
// Hide the toolbar, including mute and speed
showEditor(videoUri, { enableEditTools: false });
```

## What happens on export

When any transform is applied, the video is re-encoded with the hardware encoder (`h264_videotoolbox` on iOS, `h264_mediacodec` on Android) at the source bitrate to preserve quality. As a side effect, the cut is frame accurate, just as with [precise trimming](/guide/precise-trimming).

On Android, if the hardware encoder fails to start, the [encoder fallback](/guide/android-encoder-fallback) takes over.

## Theme

The crop brackets and grid are white in the dark theme and black in the light theme. When the user rotates the video, the overlay cross-fades instead of rotating with it. See [Theming](/guide/theming).
