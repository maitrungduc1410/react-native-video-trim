---
name: Fix Critical and High Bugs
overview: Fix all 13 Critical (5) and High (8) severity issues found during the deep analysis across iOS Swift, Android Kotlin, and shared configuration files.
todos:
  - id: c1
    content: "[Critical] Fix thumbnail index desync crash in ios/VideoTrimmer.swift"
    status: completed
  - id: c2
    content: "[Critical] Register LifecycleEventListener + add cleanup() in BaseVideoTrimModule.kt"
    status: completed
  - id: c3
    content: "[Critical] Fix MediaMetadataRetriever race with lock in VideoTrimmerView.kt"
    status: completed
  - id: c4
    content: "[Critical] Guard force-unwrap crashes in deleteFile/isValidFile in VideoTrim.swift"
    status: completed
  - id: c5
    content: "[Critical] Marshal FFmpeg/Promise callbacks to UI thread in VideoTrimmerUtil.kt, MediaMetadataUtil.kt, BaseVideoTrimModule.kt"
    status: completed
  - id: h1
    content: "[High] Fix wrong cancel-trimming dialog button labels in VideoTrim.swift"
    status: completed
  - id: h2
    content: "[High] Guard all outputFile! force-unwraps in VideoTrim.swift FFmpeg callbacks + delegates"
    status: completed
  - id: h3
    content: "[High] Scope FileProvider to files-path and cache-path in file_paths.xml"
    status: completed
  - id: h4
    content: "[High] Add path traversal protection to StorageUtil.deleteFile"
    status: completed
  - id: h5
    content: "[High] Fix URL(string:) for local paths + showEditor force-unwrap in VideoTrim.swift"
    status: completed
  - id: h6
    content: "[High] Remove duplicate onHide emission from closeEditor in BaseVideoTrimModule.kt"
    status: completed
  - id: h7
    content: "[High] Replace all currentActivity!! with null-safe access across Android files"
    status: completed
  - id: h8
    content: "[High] Replace legacy KVO with NSKeyValueObservation in VideoTrimmerViewController.swift"
    status: completed
isProject: false
---

# Fix All Critical + High Severity Issues

## Files to modify

- [ios/VideoTrimmer.swift](ios/VideoTrimmer.swift) -- thumbnail crash
- [ios/VideoTrim.swift](ios/VideoTrim.swift) -- force-unwraps, wrong labels, outputFile guards, URL handling, vc cleanup
- [ios/VideoTrimmerViewController.swift](ios/VideoTrimmerViewController.swift) -- KVO imbalance
- [android/src/main/java/com/videotrim/BaseVideoTrimModule.kt](android/src/main/java/com/videotrim/BaseVideoTrimModule.kt) -- lifecycle, duplicate event, activity nulls, FFmpeg threading
- [android/src/main/java/com/videotrim/widgets/VideoTrimmerView.kt](android/src/main/java/com/videotrim/widgets/VideoTrimmerView.kt) -- retriever race, activity null
- [android/src/main/java/com/videotrim/utils/StorageUtil.kt](android/src/main/java/com/videotrim/utils/StorageUtil.kt) -- path traversal
- [android/src/main/java/com/videotrim/utils/VideoTrimmerUtil.kt](android/src/main/java/com/videotrim/utils/VideoTrimmerUtil.kt) -- FFmpeg callback threading
- [android/src/main/java/com/videotrim/utils/MediaMetadataUtil.kt](android/src/main/java/com/videotrim/utils/MediaMetadataUtil.kt) -- promise thread
- [android/src/main/res/xml/file_paths.xml](android/src/main/res/xml/file_paths.xml) -- broad FileProvider scope

---

## Critical Fixes (5)

### C1. Thumbnail index desync crash -- `VideoTrimmer.swift:449-464`

The `seenIndex` counter increments on every callback including failed frames, but the `guard let cgImage` early-returns without placing a thumbnail. Subsequent frames map to wrong indices; if enough fail, `newThumbnails[seenIndex - 1]` goes **out of bounds**.

**Fix:** Remove `seenIndex`. Match thumbnails by `requestedTime` instead:

```swift
generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgImage, actualTime, result, error in
    DispatchQueue.main.async {
        guard let cgImage = cgImage else { return }
        guard let index = newThumbnails.firstIndex(where: { CMTimeCompare($0.time, requestedTime) == 0 }) else { return }
        let image = UIImage(cgImage: cgImage)
        let imageView = newThumbnails[index].imageView
        UIView.transition(with: imageView, duration: 0.25, options: [.transitionCrossDissolve], animations: {
            imageView.image = image
        })
    }
}
```

### C2. `LifecycleEventListener` never registered -- `BaseVideoTrimModule.kt:62`

`BaseVideoTrimModule` implements `LifecycleEventListener` but never calls `addLifecycleEventListener(this)`. Lifecycle callbacks (`onHostPause`, `onHostDestroy`) never fire.

**Fix:** Add registration in `init` block:

```kotlin
init {
    reactApplicationContext.addLifecycleEventListener(this)
    // ... existing mActivityEventListener code ...
}
```

Add a `cleanup()` method that calls `removeLifecycleEventListener(this)`.

### C3. `MediaMetadataRetriever` race on destroy -- `VideoTrimmerView.kt:462-476,1026-1104`

Background threads call `getFrameAtTime()` while `onDestroy()` calls `release()` concurrently. No synchronization.

**Fix:** Add a lock and a `@Volatile` released flag:

```kotlin
private val retrieverLock = Object()
@Volatile private var retrieverReleased = false
```

- In `onDestroy()`: `synchronized(retrieverLock) { retrieverReleased = true; retriever?.release() }`
- In progressive thumbnail gen: `synchronized(retrieverLock) { if (retrieverReleased) null else retriever?.getFrameAtTime(...) }`
- Also cancel `"progressive_thumbs"` in `onDestroy`

### C4. Force-unwrap crashes on public API inputs -- `VideoTrim.swift:888,921`

`deleteFile(uri:)` does `URL(string: uri)!` and `isValidFile(url:)` does `URL(string: url)!`. Any invalid string from JS crashes.

**Fix:**
- `deleteFile`: `guard let url = URL(string: uri) else { return false }`
- `isValidFile`: `guard let fileURL = URL(string: url) ?? URL(fileURLWithPath: url) as URL? else { completion([...false...]); return }`

### C5. FFmpeg/Promise callbacks on wrong thread -- `VideoTrimmerUtil.kt:82-124`, `MediaMetadataUtil.kt:46-78`, `BaseVideoTrimModule.kt:608-667`

FFmpeg completion callbacks and `checkFileValidity` raw `Thread` resolve promises/emit events from non-RN threads.

**Fix:**
- `VideoTrimmerUtil.trim`: Wrap all `callback.*` calls inside `UiThreadUtil.runOnUiThread { ... }`
- `MediaMetadataUtil.checkFileValidity`: Wrap `callback.onResult(...)` in `UiThreadUtil.runOnUiThread { ... }`
- `BaseVideoTrimModule.trim` (the standalone trim): Wrap `promise.resolve`/`promise.reject` calls in `UiThreadUtil.runOnUiThread { ... }`

---

## High Fixes (8)

### H1. Wrong dialog button labels for cancel-trimming -- `VideoTrim.swift:296,310`

The cancel-**trimming** confirmation dialog uses `cancelDialogConfirmText`/`cancelDialogCancelText` (the cancel-**editor** strings) instead of the trimming-specific variants.

**Fix:** Replace with `self.cancelTrimmingDialogConfirmText` and `self.cancelTrimmingDialogCancelText`.

### H2. `outputFile!` force-unwraps in FFmpeg callbacks -- `VideoTrim.swift:357,375,386,393,398,407`

**Fix:** Before the FFmpeg command block, add `guard let outputFile = outputFile else { ... return }`. Then replace all `self.outputFile!` with the local binding. Also fix `outputFile!` in share completion handler and document picker delegates by using `if let outputFile = self.outputFile`.

### H3. `FileProvider` exposes all external storage -- `file_paths.xml`

`<external-path name="external_files" path="." />` exposes everything.

**Fix:** Replace with scoped paths:

```xml
<paths xmlns:android="http://schemas.android.com/apk/res/android">
  <files-path name="internal_files" path="." />
  <cache-path name="cache_files" path="." />
</paths>
```

### H4. Arbitrary file deletion via path traversal -- `StorageUtil.kt:39-42`

`deleteFile(path)` passes any JS string directly to `File()`.

**Fix:** Canonicalize and validate:

```kotlin
fun deleteFile(path: String?): Boolean {
    if (TextUtils.isEmpty(path)) return true
    val file = File(path!!).canonicalFile
    val allowedDir = BaseUtils.getContext().filesDir.canonicalFile
    if (!file.path.startsWith(allowedDir.path)) return false
    return deleteFile(file)
}
```

### H5. `URL(string:)` fails for local file paths in `_trim` and `showEditor` -- `VideoTrim.swift:482,730-731`

`URL(string:)` returns nil for plain paths like `/var/mobile/...`. Also, `showEditor` force-unwraps `destPath!` in a `print` before the guard.

**Fix:**
- `_trim`: `guard let destPath = URL(string: inputFile) ?? URL(fileURLWithPath: inputFile) as URL? else { ... }`
- `showEditor`: Move the guard **before** the print. Use `URL(string: uri) ?? URL(fileURLWithPath: uri)`.

### H6. Duplicate `onHide` event emission -- `BaseVideoTrimModule.kt:551-554`

`closeEditor()` calls `hideDialog(true)` (which triggers `OnDismissListener` that emits `onHide`) then emits `onHide` again.

**Fix:** Remove `sendEvent("onHide", null)` from `closeEditor()`, since `hideDialog` already triggers it via the dismiss listener.

### H7. `currentActivity!!` force-unwraps throughout -- `BaseVideoTrimModule.kt` and `VideoTrimmerView.kt`

Multiple `currentActivity!!` and `activity!!` calls that crash if activity is null.

**Fix:** Replace with null-safe access + early return in each location:
- `showEditor`: `val activity = reactApplicationContext.currentActivity ?: run { onError(...); return }`
- `onCancel`, `onSave`, `startTrim`: `val activity = ... ?: return`
- `changeStatusBarColor`: already uses `?.let`, just fix the nested `currentActivity!!`
- `VideoTrimmerView.init`: `context.currentActivity?.requestedOrientation = ...`
- `onFailToLoadMedia`: `mContext.currentActivity?.let { ... } ?: return true`
- Also replace `!editorConfig?.getBoolean(...)!!` with `editorConfig?.getBoolean(...) != true` to avoid double-bang on nullable config

### H8. KVO removal imbalance in `VideoTrimmerViewController` -- lines 193-212

`player.removeObserver(self, forKeyPath: "status")` in `viewWillDisappear` throws if never added (e.g. asset failed before `setupPlayerController`).

**Fix:** Replace legacy KVO with modern `NSKeyValueObservation`:
- Add property: `private var statusObservation: NSKeyValueObservation?`
- In `setupPlayerController`: `statusObservation = player.observe(\.status, options: [.new, .initial]) { ... }`
- In `viewWillDisappear`: `statusObservation?.invalidate(); statusObservation = nil`
- Extract the `observeValue` body into a private `onPlayerReady()` method called from the observation closure (dispatched to main queue)
- Also guard `asset!` in `setupPlayerController` with `guard let asset = asset else { return }`

---

## Additional safe guards applied along the way

These are part of the H2/H5/H7 fixes but worth calling out:
- `vc!.asset!` in `showEditor` saveBtnClicked closure -> `guard let asset = vc.asset else { return }`
- `closeEditor` -> set `self.vc = nil` in dismiss completion to release the controller
- `assetLoaderDidSucceed` -> `loader.asset?.duration` instead of `loader.asset!.duration`