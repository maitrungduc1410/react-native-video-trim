# react-native-video-trim

## 8.3.1

### Patch Changes

- 41fc35d: Fix the Android editor leaking its player when closed before the video finished loading. With `autoplay` the audio could start playing after the editor was gone.
- 41fc35d: Fix the Android progress dialog staying on screen when the user backs out of the document picker opened by `openDocumentsOnFinish`. The editor also no longer reacts to activity results it did not request.
- 41fc35d: Fix `getFrameAt()` on Android returning a downscaled image for portrait recordings.
- 41fc35d: Fix `EditorConfig.jumpToPositionOnLoad` on Android being read as seconds instead of milliseconds, which made the editor jump to the end of the selection.
- 41fc35d: Fix `merge()` on Android turning portrait recordings into a landscape video with black bars. The target size now follows the first clip's rotation.
- 41fc35d: Restore the host Activity on Android when the editor closes: the screen orientation lock is put back instead of being reset, and `changeStatusBarColorOnOpen` restores the original status bar flags.
- 41fc35d: Fix `EditorConfig.cancelTrimmingButtonText` being ignored on both platforms.
- 41fc35d: Accept plain absolute paths (`/var/...`) everywhere on iOS, not only `file://` URIs. `showEditor()`, `getFrameAt()`, `isValidFile()`, `saveToPhoto()`, `saveToDocuments()`, `share()` and `deleteFile()` failed on them, and `mixAudio()` silently dropped the video's original audio.
- 41fc35d: Fix the `compress()` quality presets on iOS. They had no effect and every preset encoded at a very low bitrate; they now target 500 kbps, 2 Mbps and 5 Mbps like Android.
- 41fc35d: Fix editor events never reaching JS on iOS (New Architecture) when `trim()` was called before the first `showEditor()`.
- 41fc35d: Fix trimming remote files on iOS. `showEditor()` and `trim()` passed only the path of an HTTPS URL to FFmpeg, so saving always failed with a file not found error.
- 41fc35d: Fix a crash on iPad when opening the share sheet through `share()` or `openShareSheetOnFinish`.
- 41fc35d: Clamp `speed` to the documented 0.25 to 4.0 range. A speed of 0 or below used to hang `trim()` and the editor export.
- 41fc35d: The trimming progress bar now tracks the selected range instead of the whole source, so it reaches 100%. `onFinishTrimming.duration` is the duration of the trimmed clip, as documented, not of the source file.
- 41fc35d: Options passed as `undefined` or `null` now fall back to their defaults instead of crashing the native side. `showEditor()` can also be called without a config object.

## 8.2.4

### Patch Changes

- f956dc3: Export TypeScript types for `showEditor()` options (`EditorOptions`) and for editor events (`VideoTrimEventMap`, `VideoTrimEvent`, `FinishTrimmingEvent`, `ErrorCode`, ...), and type the default export, so `VideoTrim.onFinishTrimming(...)` no longer needs an `as Spec` cast. Types only, no runtime change.

## Older releases

Releases up to 8.2.3 are documented in
[GitHub Releases](https://github.com/maitrungduc1410/react-native-video-trim/releases).
