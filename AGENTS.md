# AGENTS.md — react-native-video-trim

## Project Overview

React Native library for trimming video and audio. Supports both the **Old Architecture** (Bridge) and **New Architecture** (Fabric/TurboModules). Built with `react-native-builder-bob`, Yarn 4 workspaces, and TypeScript. Uses **FFmpegKit** for media processing on both platforms.

- **iOS**: Swift + Obj-C++ (`AVFoundation`, `AVKit`, `UIKit`, `Photos`, FFmpegKit)
- **Android**: Kotlin + Java (`FFmpeg-mobile`, `MediaMetadataRetriever`, `FileProvider`)
- **JS/TS**: TurboModule spec with codegen (`VideoTrimSpec`)

## Repository Layout

```
src/                          # TypeScript source — public API, TurboModule spec, old-arch bridge
  index.tsx                   # Entry point: architecture detection, factory functions, exported API
  NativeVideoTrim.ts          # TurboModule Spec (codegen source of truth for API surface & events)
  OldArch.ts                  # NativeModules fallback for Old Architecture
  __tests__/                  # Jest tests (placeholder)

ios/                          # Flat directory — all Swift/Obj-C++ native code
  VideoTrim.mm                # Dual-arch RN bridge (New Arch: NativeVideoTrimSpecBase, Old Arch: RCT_EXTERN)
  VideoTrim.swift             # Core implementation: RCTEventEmitter, FFmpeg trim, editor, file helpers
  VideoTrimProtocol.swift     # Delegate protocol for New Arch event forwarding
  VideoTrimmerViewController.swift  # Full-screen editor UI (theme, transforms, crop, player lifecycle)
  VideoTrimmer.swift          # Custom UIControl trimmer (thumbnails, handles, scrub, zoom, waveform)
  VideoTrimmerThumb.swift     # Trimmer handle visuals
  AudioWaveformView.swift     # UIView that renders audio waveform bars (rounded-rect, normalised amplitudes)
  CropOverlayView.swift       # Freeform crop overlay (brackets, grid, drag/pinch, theme-aware colors)
  AssetLoader.swift           # Async AVURLAsset loading
  ErrorCode.swift             # Error code enum
  ProgressAlertController.swift  # Modal progress UI during FFmpeg trim
  VideoTrim-Bridging-Header.h # Swift/Obj-C interop

android/
  build.gradle                # Library module: plugins, SDK versions, source sets, FFmpeg dependency
  gradle.properties           # Default SDK/NDK/FFmpeg versions
  src/main/                   # Shared base classes, UI, utilities
    java/com/videotrim/
      BaseVideoTrimModule.kt  # Core logic: editor, FFmpeg, file ops, VideoTrimListener
      VideoTrimPackage.kt     # NativeModule registration
      enums/ErrorCode.java
      interfaces/             # VideoTrimListener, IVideoTrimmerView
      utils/                  # MediaMetadataUtil, StorageUtil, VideoTrimmerUtil
      widgets/VideoTrimmerView.kt    # Full-screen trimmer UI (theme, transforms, crop, player lifecycle, waveform)
      widgets/AudioWaveformView.kt   # Custom View that renders audio waveform bars (rounded-rect, normalised amplitudes)
      widgets/CropOverlayView.kt     # Freeform crop overlay (brackets, grid, drag/pinch, theme-aware colors)
    java/iknow/android/utils/ # Screen, dp/px, background/UI thread helpers
    res/                      # Drawables, layout, colors, strings, file_paths.xml
  src/oldarch/                # Old Architecture module (ReactModule, DeviceEventEmitter)
  src/newarch/                # New Architecture module (TurboModule, codegen emitters)

example/                      # Yarn workspace example app
  src/App.tsx                 # Active demo (New Arch event listeners)
  src/App.OldArch.tsx         # Old Arch demo (NativeEventEmitter)

VideoTrim.podspec             # CocoaPods spec (reads FFMPEGKIT_PACKAGE env var)
```

## Architecture & Data Flow

### Architecture Detection

Runtime detection in `src/index.tsx`:

```typescript
const isFabric = !!(global as any).nativeFabricUIManager;
const VideoTrim = isFabric
  ? require('./NativeVideoTrim').default
  : require('./OldArch').default;
```

### Native Module Name

The module is registered as `"VideoTrim"` on both platforms and both architectures.

### Event System

Both platforms emit the same logical events: `onShow`, `onHide`, `onLoad`, `onStartTrimming`, `onFinishTrimming`, `onCancelTrimming`, `onCancel`, `onLog`, `onStatistics`, `onError`.

- **Old Architecture**: a single native event `"VideoTrim"` is emitted. The payload includes a `"name"` field with the logical event name. JS listens via `NativeEventEmitter`.
- **New Architecture**: each logical event maps to a dedicated codegen emitter (`emitOnLoad`, `emitOnFinishTrimming`, etc.) declared on the `Spec` as `EventEmitter<T>` fields.

### Factory Functions

`src/index.tsx` provides factory functions (`createBaseOptions`, `createEditorConfig`, `createTrimOptions`, `createCompressOptions`, `createFrameExtractionOptions`, `createExtractAudioOptions`, `createGifOptions`, `createMergeOptions`) that merge user overrides with defaults and run `processColor` on color string props before passing to native.

### Headless APIs

In addition to the editor UI (`showEditor`) and headless trim (`trim`), the library provides several headless (no-UI) media processing APIs:

| API | Description | FFmpeg | Platform-native |
|-----|-------------|--------|-----------------|
| `getFrameAt` | Extract a single frame as JPEG/PNG | — | `AVAssetImageGenerator` (iOS), `MediaMetadataRetriever` (Android) |
| `extractAudio` | Strip video, keep audio track | `-vn` | — |
| `compress` | Re-encode with quality/bitrate/resolution controls | h264_videotoolbox / h264_mediacodec | — |
| `toGif` | Two-pass palette-based GIF conversion | `palettegen` + `paletteuse` | — |
| `merge` | Concatenate multiple clips into one | concat filter + re-encode | — |

**Key decisions:**
- `extractAudio` defaults to `m4a` (AAC) because the default FFmpegKit builds lack `libmp3lame` for mp3 encoding.
- `merge` uses the concat **filter** (`-filter_complex concat=n=N:v=1:a=1`) rather than the concat **demuxer** (`-f concat -c copy`). Each input is normalized to the first clip's resolution and frame rate via `scale+pad+setsar+format+fps` filters before entering the concat, so clips with different dimensions, pixel formats, SARs, or frame rates merge correctly (mismatched aspect ratios get letterboxed/pillarboxed with black bars; frame rate is capped at 30 fps to prevent massive frame duplication).
- `merge` probes all input videos for bitrate and uses the maximum as the output target (`-b:v`) to preserve quality. Falls back to 10 Mbps.
- `merge` only supports **local file paths**. Remote URLs are not supported because the default FFmpegKit build disables OpenSSL.
- `getFrameAt` explicitly sets full-resolution output: `AVAssetImageGenerator.maximumSize` on iOS (to the video's natural size), `MediaMetadataRetriever.getScaledFrameAtTime` on Android (API 27+).
- All FFmpeg-based headless APIs include full FFmpeg log output in error messages for debugging.

### Utility Functions

Three standalone utility functions handle saving/sharing output files from any API:

| Function | iOS Implementation | Android Implementation |
|----------|-------------------|----------------------|
| `saveToPhoto` | `PHPhotoLibrary` — detects image vs video by extension, calls appropriate `PHAssetChangeRequest` factory | `MediaStore` — dispatches to `Images.Media` or `Video.Media` collection based on extension, uses `IS_PENDING` pattern on Q+ |
| `saveToDocuments` | `UIDocumentPickerViewController` in `exportToService` mode | `ACTION_CREATE_DOCUMENT` via SAF (Storage Access Framework) |
| `share` | `UIActivityViewController` | `ACTION_SEND` with `FileProvider` content URI |

### File Storage Strategy

| Output source | Directory | Lifecycle |
|---------------|-----------|-----------|
| `showEditor`, `trim` | Documents / filesDir (persistent) | Survives app restarts, must be manually deleted |
| `getFrameAt`, `extractAudio`, `compress`, `toGif`, `merge` | Caches / cacheDir | OS may purge under storage pressure |

`listFiles()` and `cleanFiles()` scan **both** directories. `deleteFile()` validates paths against both allowed directories before deletion.

### Encoder Fallback Chain (Android only)

The Android re-encode path uses an encoder fallback chain in `VideoTrimmerUtil.executeWithEncoderFallback`:

1. **`h264_mediacodec`** — hardware H.264, fast, default. Keeps the source resolution.
2. **`hevc_mediacodec`** — hardware H.265/HEVC (`-tag:v hvc1` for Apple-player compatibility). Different MediaCodec component than the H.264 encoder, so it often configures on devices whose H.264 encoder is broken (LG G8 ThinQ). Hardware-fast, full resolution, decodable on modern Android + iOS. No external lib needed (MediaCodec is a system library, present in every build incl. `min`).
3. **`mpeg4 -q:v 3`** — software MPEG-4 Part 2, always present in every FFmpegKit build, lower quality. Downscaled so the long side ≤ `VideoTrimmerUtil.MPEG4_FALLBACK_MAX_LONG_SIDE` (1280px) because Android's software MPEG-4 decoder rejects full-res mpeg4 (`NO_EXCEEDS_CAPABILITIES`) — the file would otherwise encode fine but fail to play back on-device / in ExoPlayer. The cap is carried on `EncoderConfig.maxLongSide` and applied per call site (see the pattern snippet below).

When an attempt fails, `runAttempt` retries the next rung if either `VideoTrimmerUtil.classifyFFmpegError` matched a hardware signature (`MediaCodec configure failed` / `Error initializing output stream` + `mediacodec`) **or** the failing attempt used any `*_mediacodec` encoder (so a hardware failure with an unrecognized log still reaches the software `mpeg4` floor). A software `mpeg4` failure is never retried. Each transition emits a notice through the existing `onLog` event and logcat (no new event — keeps the JS surface minimal). The selected/succeeded/failed encoder is logged as `Encoder selected: <name>` / `Encoder succeeded: <name>` / `Encoder '<name>' failed to configure…` via both logcat (`VideoTrimmerUtil` tag) and `onLog`. If every attempt fails, the editor path emits `onError` with `ErrorCode.HARDWARE_ENCODER_FAILED`; the headless paths reject the Promise with their original error message format (`"Compression failed: rc N\n<logs>"` etc.).

Every Android entry point that opens a video encoder routes through the helper:

| Entry point | File | Cancellation |
|-------------|------|--------------|
| `VideoTrimmerUtil.trim` (editor save) | `utils/VideoTrimmerUtil.kt` | Returns `TrimSession` handle so `VideoTrimmerView` can cancel across attempts via `trimSession.cancel()` |
| `BaseVideoTrimModule.trim` (headless) | `BaseVideoTrimModule.kt` | Discards handle — headless trim is not user-cancellable |
| `BaseVideoTrimModule.compress` | `BaseVideoTrimModule.kt` | Same as headless trim |
| `BaseVideoTrimModule.merge` | `BaseVideoTrimModule.kt` | Same as headless trim |

`TrimCallbacks.onError` has signature `(message: String, code: ErrorCode, session: FFmpegSession?) -> Unit`. Callers can use the default `message` (editor save, headless trim) or extract `session.allLogsAsString` / `session.returnCode` to build a custom message (compress, merge — which preserve their pre-existing `"<X> failed: rc N\n<full logs>"` rejection format so consumers matching on that prefix don't break).

**Why this is Android-only:**

- Android's `h264_mediacodec` goes through OMX / MediaCodec → vendor IL → vendor hardware. Every chipset vendor (Qualcomm, MediaTek, Samsung, Huawei, Unisoc, …) ships their own implementation with their own quirks; configure-time rejection of valid H.264 inputs is real and reproducible (LG G8 ThinQ on Snapdragon 855, certain Samsung Galaxy models on HEVC inputs, etc.). The failure can hit any encode path — the bug is encoder-specific, not API-specific.
- iOS's `h264_videotoolbox` goes through VideoToolbox → Apple's media driver → Apple silicon. One vendor end-to-end, one curated device matrix that Apple regression-tests. No known reproducible configure-time failure on supported iOS devices.

iOS still adopts the `HARDWARE_ENCODER_FAILED` error code in `ErrorCode.swift` and `VideoTrim.classifyFFmpegError` so the cross-platform JS contract is symmetric — if the rare VideoToolbox failure does occur, consumers get the same specific `errorCode` rather than a generic `TRIMMING_FAILED`. But there is no fallback chain on iOS; the iOS classifier only re-labels the error.

**Adding a new Android API that re-encodes:** thread it through `VideoTrimmerUtil.executeWithEncoderFallback`. Don't call `FFmpegKit.executeWithArgumentsAsync` directly with `-c:v h264_mediacodec` — that bypasses the fallback and will fail on the affected devices. Pattern:

```kotlin
val buildCommand: (VideoTrimmerUtil.EncoderConfig) -> Array<String> = { config ->
  // Insert `config.args` in place of the encoder portion
  // (`-c:v h264_mediacodec -b:v <bitrate>` would have gone).
  //
  // If `config.maxLongSide != null` (set on the mpeg4 software-fallback attempt),
  // you MUST downscale so the frame's long side stays within it — otherwise the
  // mpeg4 output is undecodable on-device (Android's software MPEG-4 decoder
  // rejects full-res mpeg4 with NO_EXCEEDS_CAPABILITIES). For `-vf` chains append
  // `VideoTrimmerUtil.capLongSideFilter(it)`; for `-filter_complex` paths with
  // fixed target dimensions use `VideoTrimmerUtil.capDimensionsToLongSide(...)`.
}
VideoTrimmerUtil.executeWithEncoderFallback(
  encoderConfigs = VideoTrimmerUtil.reEncodeEncoderConfigs(bitrateStr),
  buildCommand = buildCommand,
  videoDurationMs = 0,
  callbacks = VideoTrimmerUtil.TrimCallbacks(...),
)
```

If a real iOS-device failure is ever reported, add a two-step chain (`h264_videotoolbox` → `mpeg4`) mirroring the Android shape — the classifier already returns the right code, so only the retry plumbing would be new.

### Editor Time Labels

The editor's start / current / end time labels share a single token-based formatter on each platform, controlled by the `durationFormat` option on `EditorConfig`:

| Token | Example | Notes |
|-------|---------|-------|
| `mm:ss` | `01:23` | No fractional seconds |
| `mm:ss.SS` | `01:23.45` | Centiseconds (2 fractional digits) |
| `mm:ss.SSS` | `01:23.456` | Milliseconds — **default** |
| `hh:mm:ss` | `00:01:23` | Hours-padded, no fractional |
| `hh:mm:ss.SSS` | `00:01:23.456` | Hours + ms |

Default is `mm:ss.SSS` on both platforms. Unknown tokens fall back to the default. To add a new token: extend the JSDoc enum in `src/NativeVideoTrim.ts`, the `switch` in iOS `CMTime.displayString(format:)`, and the `when` in Android `VideoTrimmerView.formatTime`.

**iOS-specific**: time labels use `UIFont.monospacedDigitSystemFont(...)` (in `UILabel.createLabel(...)` extension) so digit width is constant — without this the label width changes as digits change and the surrounding stack view re-lays out, making the label appear to "shake" while scrubbing. Android's default font already uses tabular figures so no equivalent fix is needed there.

### Audio Waveform Visualization

When the editor opens an audio file (`type: "audio"`), the thumbnail track is replaced with a waveform bar visualization. Both platforms follow the same strategy:

1. **Amplitude extraction** — PCM samples are decoded from the audio track and grouped into per-bar buckets. Each bar's height is the RMS (root-mean-square) of its bucket, normalised so the loudest bar = 1.0. This produces visually consistent output across platforms.
2. **Remote file handling** — `AVAssetReader` (iOS) and `MediaExtractor` (Android) both require (or strongly benefit from) local file access. Remote URLs are downloaded once to a temporary cache file; all subsequent reads (including zoom re-extractions) use the cached file, avoiding redundant network I/O.
3. **Zoom** — On zoom-in the visible time range narrows; the waveform is re-extracted for that sub-range at higher resolution. On zoom-out the cached full-view amplitudes are restored instantly.

#### iOS

- **Decode**: `AVAssetReader` + `AVAssetReaderTrackOutput` with 32-bit float PCM output settings.
- **Remote URL workaround**: `AVAssetReader` rejects non-local URLs. `downloadAudioForWaveform()` uses `URLSession.downloadTask` to save to a temp file with a correct file extension inferred from HTTP headers (Content-Disposition → MIME type → URL path → `m4a` fallback). iOS's `AVURLAsset` relies on the extension to identify the codec.
- **Rendering**: `AudioWaveformView` (UIView) draws all bars in a single `CGContext` pass via `UIBezierPath(roundedRect:)`.
- **Cleanup**: `deinit` + `asset.didSet` cancel the download task, asset reader, and delete the temp file. `viewWillDisappear` sets `trimmer.asset = nil` to trigger cleanup.

#### Android

- **Decode**: `MediaExtractor` (demux) → `MediaCodec` (hardware PCM decode, 16-bit short). RMS is accumulated on-the-fly into per-bar buckets.
- **Remote URL handling**: `resolveLocalAudioPath()` downloads via `HttpURLConnection` to `cacheDir` with a `.tmp` extension. Android's `MediaExtractor` probes file content for codec detection, so the extension doesn't matter.
- **Progressive display**: The decode loop fires `onProgress` callbacks at 5 % and then every 20 % of bars filled, so the UI renders incrementally.
- **Rendering**: `AudioWaveformView` (custom View) draws bars via `Canvas.drawRoundRect()`.
- **Cleanup**: `onDestroy()` sets `isGeneratingWaveform = false` (background loops check this flag), cancels named `BackgroundExecutor` tasks, and deletes the temp file via `cleanupLocalAudioFile()`.

#### JS API

Waveform options are part of `EditorConfig` in `NativeVideoTrim.ts`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `waveformColor` | color string | `"white"` | Bar fill color |
| `waveformBackgroundColor` | color string | `"#3478F6"` | Track background behind bars |
| `waveformBarWidth` | number (dp/pt) | `3` | Width of each bar |
| `waveformBarGap` | number (dp/pt) | `2` | Gap between bars |
| `waveformBarCornerRadius` | number (dp/pt) | `1.5` | Corner radius for rounded bars |

Colors are passed through `processColor()` in `src/index.tsx` before reaching native.

## Adding a New Feature

1. **Define the TypeScript interface** in `src/NativeVideoTrim.ts` — add to `Spec`, create option/result types.
2. **Create a factory function** in `src/index.tsx` (e.g. `createMyOptions`) that merges user overrides with defaults.
3. **Implement in base classes**: `ios/VideoTrim.swift` (as `@objc public static func` for New Arch class methods + Old Arch instance wrapper) and `android/.../BaseVideoTrimModule.kt`.
4. **Bridge the method** in `ios/VideoTrim.mm` (New Arch dispatch) and in both `android/src/oldarch/VideoTrimModule.kt` and `android/src/newarch/VideoTrimModule.kt`.
5. **Wire events** (if any) in both Android arch modules and in `ios/VideoTrim.mm` (`emitEventToJSWithEventName` dispatch).
6. **Export from `src/index.tsx`** — add the public function with input validation.
7. **Choose output directory**: persistent (documents/filesDir) for editor-produced files, cache (cachesDirectory/cacheDir) for headless API outputs.
8. **Test both architectures** on iOS and Android via the `example/` app.

## Adding a new `EditorConfig` field

Editor options take a different path than method arguments — they're delivered as a config struct/dict, and on **iOS New Arch** the codegen-generated C++ struct is destructured field-by-field into an `NSDictionary` before reaching Swift. **Forgetting this step is the most common reason a new option silently does nothing on iOS New Arch only**, while Android (both archs) and iOS Old Arch work fine because they pass the dict-like config through unchanged.

Checklist for any new field on `EditorConfig`:

1. **Define** the field in `EditorConfig` in `src/NativeVideoTrim.ts` with a JSDoc comment describing allowed values.
2. **Default** the field in `createEditorConfig` in `src/index.tsx`.
3. **iOS New Arch — copy into the dict** in `ios/VideoTrim.mm` inside `showEditor:config:`. Required strings: `dict[@"foo"] = config.foo();`. Optional strings: nil-check first (mirrors `theme` / `durationFormat`). Optional numbers: use the `has_value()` pattern (mirrors `trimmerColor`, `zoomOnWaitingDuration`).
4. **iOS — read in Swift** inside `VideoTrimmerViewController.configure(config:)` via `config["foo"] as? Type ?? default`. Store on a private property if the value is needed at multiple call sites.
5. **Android — read** inside `VideoTrimmerView.configure(...)` via `config.hasKey("foo")` + `config.getString/getInt/...`. No bridge step needed — `ReadableMap` reflects the JS dict directly.
6. **Test on iOS New Arch specifically** — Old Arch will work even if step 3 is skipped, hiding the bug.

## Code Style & Conventions

### Formatting

Prettier config lives in `package.json`:

- Single quotes, 2-space indent, no tabs, trailing commas (`es5`), consistent quote props.

### Linting

ESLint 9 flat config (`eslint.config.mjs`) extends `@react-native` + Prettier. Ignores `node_modules/` and `lib/`.

### TypeScript

Strict mode enabled: `strict`, `noUnusedLocals`, `noUnusedParameters`, `noUncheckedIndexedAccess`, `verbatimModuleSyntax`. Module resolution: `bundler`. JSX: `react-jsx`.

### Commits

Conventional commits enforced by `commitlint` (config in `package.json`, extends `@commitlint/config-conventional`). Pre-commit hooks managed by Lefthook (`lefthook.yml`):

- `pre-commit`: ESLint on staged files + `tsc` typecheck
- `commit-msg`: `commitlint --edit`

Commit prefixes: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`.

## Build & Development Commands

```bash
# Install dependencies (Yarn 4 with node-modules linker)
yarn

# Build library (react-native-builder-bob → lib/)
yarn prepare

# Lint & typecheck
yarn lint
yarn typecheck

# Run tests
yarn test

# Example app
yarn example start          # Metro bundler
yarn example android        # Run on Android
yarn example ios            # Run on iOS

# Native builds via Turborepo
yarn turbo run build:android
yarn turbo run build:ios

# Test specific architecture (Android)
ORG_GRADLE_PROJECT_newArchEnabled=true yarn example android   # New Arch
ORG_GRADLE_PROJECT_newArchEnabled=false yarn example android  # Old Arch

# Release (release-it with conventional changelog)
yarn release

# Clean build artifacts
yarn clean
```

Node version: pinned to `v20.19.0` (`.nvmrc`).

## CI Pipeline

GitHub Actions (`.github/workflows/ci.yml`) runs on push/PR to `main` and merge queue:

| Job | What it does |
|-----|-------------|
| `lint` | `yarn lint` + `yarn typecheck` |
| `test` | `yarn test --maxWorkers=2 --coverage` |
| `build-library` | `yarn prepare` |
| `build-android` | Turbo-cached Android build with JDK 17 |
| `build-ios` | Turbo-cached iOS build with Xcode 16.2, CocoaPods |

Caching: Yarn deps, Gradle, CocoaPods, Turborepo outputs.

## Platform-Specific Notes

### iOS

- **Podspec**: `VideoTrim.podspec` at repo root. FFmpegKit package variant is configurable via `ENV['FFMPEGKIT_PACKAGE']` (defaults to `min`). Version via `ENV['FFMPEGKIT_PACKAGE_VERSION']` (defaults to `~> 6.0`).
- **Bridge pattern**: `VideoTrim.mm` is Obj-C++ — under New Arch it subclasses `NativeVideoTrimSpecBase` and holds a `VideoTrimSwift` instance; under Old Arch it uses `RCT_EXTERN_REMAP_MODULE`. Swift class `VideoTrim` (exposed as `VideoTrimSwift` to Obj-C) is the real implementation.
- **Config dict (New Arch)**: `showEditor:config:` in `VideoTrim.mm` destructures the codegen `JS::NativeVideoTrim::EditorConfig` struct field-by-field into an `NSMutableDictionary` before handing it to Swift. Old Arch passes the dict through unchanged via `RCT_EXTERN_METHOD`. **Any new `EditorConfig` field must be added to this dict-copy block** or it will silently default on iOS New Arch only — see "Adding a new `EditorConfig` field" above.
- **Event forwarding (New Arch)**: Swift calls `delegate?.emitEventToJS(eventName:body:)` → Obj-C `VideoTrim` dispatches to codegen `emitOn*` methods.
- **Frameworks**: `AVFoundation`, `AVKit`, `UIKit`, `Photos`.
- **Theming**: `VideoTrimmerViewController` reads the `theme` prop from config and propagates `isLightTheme` to `VideoTrimmer`, `CropOverlayView`, and all alert dialogs. Light theme uses white background, black icons/text, and black crop overlay brackets/grid.
- **Background handling**: Player pauses automatically when the app resigns active (`UIApplication.willResignActiveNotification`).
- **Crop overlay animation**: Rotation triggers a cross-fade (fade out → rotate video → update crop rect → fade in) rather than rotating the overlay directly.

### Android

- **Gradle**: `android/build.gradle` (Groovy). Source sets switch between `src/oldarch` and `src/newarch` based on `newArchEnabled` project property. Codegen output goes to `generated/`.
- **Composition pattern**: `VideoTrimModule` wraps `BaseVideoTrimModule` (not inheritance). The `sendEvent` lambda bridges to arch-specific emission.
- **Old Arch events**: `DeviceEventManagerModule.RCTDeviceEventEmitter.emit(NAME, map)` — single event `"VideoTrim"` with logical name in payload.
- **New Arch events**: `when(eventName)` dispatch to codegen `emitOn*` methods.
- **FFmpeg dependency**: `io.github.maitrungduc1410:ffmpeg-kit-<package>:<version>` configurable via `gradle.properties` or consumer's root `ext`/properties.
- **FileProvider**: Declared in `AndroidManifest.xml` for file sharing/saving.
- **Min SDK**: 24, Target: 34, Compile: 35.
- **Theming**: `VideoTrimmerView` reads the `theme` prop and calls `applyThemeColors()` to set background/text/icon colors and crop overlay bracket/grid colors. Light theme uses white background, black icons/text, and black crop brackets/grid.
- **Background handling**: `BaseVideoTrimModule` implements `LifecycleEventListener`; `onHostPause` pauses the media player. `onSurfaceTextureDestroyed` returns `false` to keep the SurfaceTexture alive, preserving the video frame across backgrounding.
- **Haptic feedback**: Uses lighter amplitudes (30 for light feedback, 80 for heavy) and triggers haptic when trimmer handles hit absolute video boundaries (start/end of timeline).
- **Crop overlay animation**: Same cross-fade pattern as iOS during rotation.

## Testing

- **Unit tests**: Jest with `react-native` preset. Currently a placeholder (`src/__tests__/index.test.tsx`).
- **Manual testing**: Use the `example/` app. `example/src/App.tsx` demonstrates all API functions and event listeners.
- **Architecture verification**: Metro logs `"fabric":true` when running New Architecture.

## Release

Uses `release-it` with `@release-it/conventional-changelog` (Angular preset). Bumps version, creates git tag (`v${version}`), publishes to npm, creates GitHub release. Run: `yarn release`.

## Key Files Reference

| File | Purpose |
|------|---------|
| `src/NativeVideoTrim.ts` | TurboModule Spec — source of truth for API surface, events, option/result types |
| `src/index.tsx` | Public JS API, architecture detection, factory functions for all APIs |
| `src/OldArch.ts` | Old Architecture NativeModules bridge |
| `ios/VideoTrim.mm` | iOS dual-arch native bridge |
| `ios/VideoTrim.swift` | iOS core: editor, headless APIs (trim/compress/toGif/merge/extractAudio/getFrameAt), utilities (saveToPhoto/saveToDocuments/share), file management |
| `ios/VideoTrimmerViewController.swift` | iOS editor UI — theme, transforms, crop, player lifecycle, speed menu (UIMenu on iOS 14+) |
| `ios/VideoTrimmer.swift` | iOS trimmer control — timeline, thumbnails, handles, waveform |
| `ios/AudioWaveformView.swift` | iOS waveform bar renderer |
| `ios/CropOverlayView.swift` | iOS crop overlay — brackets, grid, theme-aware colors |
| `android/.../BaseVideoTrimModule.kt` | Android core: editor, headless APIs, utilities, file management, activity result handling |
| `android/.../utils/StorageUtil.kt` | Android file paths, gallery saving (image/video dispatch, IS_PENDING pattern), cache/persistent directory management |
| `android/.../widgets/VideoTrimmerView.kt` | Android editor UI — theme, transforms, crop, player lifecycle, waveform, speed PopupMenu |
| `android/.../widgets/AudioWaveformView.kt` | Android waveform bar renderer |
| `android/.../widgets/CropOverlayView.kt` | Android crop overlay — brackets, grid, theme-aware colors |
| `android/src/oldarch/VideoTrimModule.kt` | Android Old Arch module |
| `android/src/newarch/VideoTrimModule.kt` | Android New Arch module |
| `VideoTrim.podspec` | CocoaPods spec for iOS |
| `android/build.gradle` | Android library Gradle config |
| `package.json` | Scripts, dependencies, prettier, commitlint, bob, codegen config |
| `.github/workflows/ci.yml` | CI pipeline |
| `CONTRIBUTING.md` | Contributor guide |