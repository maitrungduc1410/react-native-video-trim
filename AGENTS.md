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

`src/index.tsx` provides `createBaseOptions`, `createEditorConfig`, and `createTrimOptions` that merge user overrides with defaults and run `processColor` on color string props before passing to native.

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

1. **Define the TypeScript interface** in `src/NativeVideoTrim.ts` — add to `Spec`, update relevant option types (`BaseOptions`, `EditorConfig`, `TrimOptions`).
2. **Implement in base classes**: `ios/VideoTrim.swift` and `android/.../BaseVideoTrimModule.kt`.
3. **Wire events** (if any) in both `android/src/oldarch/VideoTrimModule.kt` and `android/src/newarch/VideoTrimModule.kt`, and in `ios/VideoTrim.mm` (`emitEventToJSWithEventName` dispatch).
4. **Export from `src/index.tsx`** — add helper function if needed, update factory defaults.
5. **Test both architectures** on iOS and Android via the `example/` app.

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
| `src/NativeVideoTrim.ts` | TurboModule Spec — source of truth for API surface and events |
| `src/index.tsx` | Public JS API, architecture detection, factory functions |
| `src/OldArch.ts` | Old Architecture NativeModules bridge |
| `ios/VideoTrim.mm` | iOS dual-arch native bridge |
| `ios/VideoTrim.swift` | iOS core implementation |
| `ios/VideoTrimmerViewController.swift` | iOS editor UI — theme, transforms, crop, player lifecycle |
| `ios/VideoTrimmer.swift` | iOS trimmer control — timeline, thumbnails, handles, waveform |
| `ios/AudioWaveformView.swift` | iOS waveform bar renderer |
| `ios/CropOverlayView.swift` | iOS crop overlay — brackets, grid, theme-aware colors |
| `android/.../BaseVideoTrimModule.kt` | Android core implementation |
| `android/.../widgets/VideoTrimmerView.kt` | Android editor UI — theme, transforms, crop, player lifecycle, waveform |
| `android/.../widgets/AudioWaveformView.kt` | Android waveform bar renderer |
| `android/.../widgets/CropOverlayView.kt` | Android crop overlay — brackets, grid, theme-aware colors |
| `android/src/oldarch/VideoTrimModule.kt` | Android Old Arch module |
| `android/src/newarch/VideoTrimModule.kt` | Android New Arch module |
| `VideoTrim.podspec` | CocoaPods spec for iOS |
| `android/build.gradle` | Android library Gradle config |
| `package.json` | Scripts, dependencies, prettier, commitlint, bob, codegen config |
| `.github/workflows/ci.yml` | CI pipeline |
| `CONTRIBUTING.md` | Contributor guide |
