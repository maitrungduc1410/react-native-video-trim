---
name: Precise Frame Trimming
overview: Add an `enablePreciseTrimming` option to both the editor and headless trim APIs. When enabled, FFmpeg re-encodes the video instead of using stream copy (`-c copy`), allowing frame-accurate cuts instead of keyframe-aligned cuts.
todos:
  - id: ts-api
    content: Add `enablePreciseTrimming` to `BaseOptions` in NativeVideoTrim.ts and default in index.tsx
    status: completed
  - id: ios-bridge
    content: Pass `enablePreciseTrimming` through VideoTrim.mm for both trim and showEditor
    status: completed
  - id: ios-impl
    content: Use the flag in VideoTrim.swift for both editor trim and headless trim re-encode branching
    status: completed
  - id: android-util
    content: Add parameter to VideoTrimmerUtil.trim() and widen needsReEncode condition
    status: completed
  - id: android-view
    content: Store and pass enablePreciseTrimming in VideoTrimmerView.kt
    status: completed
  - id: android-headless
    content: Add re-encode branch to BaseVideoTrimModule.kt headless trim
    status: completed
isProject: false
---

# Precise Frame Trimming (Re-encode Option)

## Problem

Currently, both the editor trim (when no transforms are applied) and the headless `trim()` API use FFmpeg's `-c copy` (stream copy). This is fast but only cuts at keyframes, meaning the actual start/end points can drift by up to several seconds from what the user selected. When a user applies rotation/flip/crop, re-encoding already happens (for the transforms), so precise trimming comes for free. But for plain trims with no transforms, there is no way to get frame-accurate cuts.

## Solution

Add an `enablePreciseTrimming: boolean` option. When `true`, FFmpeg re-encodes the video using the platform's hardware encoder instead of stream copy, giving frame-accurate start/end points.

## Files to Change

### 1. TypeScript API — `src/NativeVideoTrim.ts`

- Add `enablePreciseTrimming: boolean` to the `BaseOptions` interface (shared by both `EditorConfig` and `TrimOptions`)

### 2. JS defaults — `src/index.tsx`

- Add `enablePreciseTrimming: false` to the `createBaseOptions` function (default off for backward compatibility)

### 3. iOS bridge — `ios/VideoTrim.mm`

- Pass `enablePreciseTrimming` through the dictionary in both the New Arch `trim:` method and the `showEditor:` method

### 4. iOS implementation — `ios/VideoTrim.swift`

**Editor trim** (the `private func trim(viewController:...)` method around line 329):
- Read `enablePreciseTrimming` from the config
- Change `needsReEncode` condition to: `hasUserTransform || cropNorm != nil || enablePreciseTrimming`
- This means when the flag is on, even a plain trim with no transforms will go through the re-encode path (h264_videotoolbox + original bitrate)

**Headless trim** (`_trim` function around line 590):
- Read `enablePreciseTrimming` from the config dictionary
- When `true`, use the re-encode command (`-noautorotate`, `-c:v h264_videotoolbox`, `-b:v <bitrate>`, `-c:a copy`) instead of `-c copy`
- When `false`, keep the existing `-c copy` behavior

### 5. Android editor trim — `android/.../VideoTrimmerUtil.kt`

- Add `enablePreciseTrimming: Boolean` parameter to the `trim()` function
- Change `needsReEncode` condition to: `hasUserTransform || cropNormalized != null || enablePreciseTrimming`
- This routes plain trims through the existing re-encode path (h264_mediacodec + bitrate)

### 6. Android editor view — `android/.../widgets/VideoTrimmerView.kt`

- Store `enablePreciseTrimming` from the config in `configure()`
- Pass it to `VideoTrimmerUtil.trim()` in `onSaveClicked()`

### 7. Android headless trim — `android/.../BaseVideoTrimModule.kt`

- Read `enablePreciseTrimming` from the options map in the `trim()` function
- When `true`, use the re-encode path (`-c:v h264_mediacodec`, `-b:v <bitrate>`, `-c:a copy`) instead of `-c copy`
- Extract bitrate from `MediaMetadataRetriever` for quality preservation

## Design Decisions

- **Default `false`**: Backward compatible. Stream copy is much faster and sufficient for most use cases.
- **Reuses existing re-encode paths**: No new FFmpeg command patterns needed. The editor already has a working re-encode branch on both platforms; we just widen the condition that triggers it.
- **Applies to both editor and headless**: The option lives in `BaseOptions`, so it is available in both `EditorConfig` (editor UI) and `TrimOptions` (headless `trim()` call).