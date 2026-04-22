---
name: Utility APIs and Cache Dir
overview: Add three standalone utility functions (saveToPhoto, saveToDocuments, share) and move headless API outputs from the documents/files directory to the cache directory, updating listFiles/cleanFiles to scan both locations.
todos:
  - id: ts-api
    content: Add saveToPhoto/saveToDocuments/share interfaces and methods to NativeVideoTrim.ts and index.tsx
    status: completed
  - id: ios-utility
    content: Implement saveToPhoto/saveToDocuments/share as public static methods in VideoTrim.swift + bridge in VideoTrim.mm
    status: completed
  - id: android-utility
    content: Implement saveToPhoto/saveToDocuments/share in BaseVideoTrimModule.kt + wire up in arch modules and spec
    status: completed
  - id: ios-cache
    content: Move 5 headless API outputs to cachesDirectory in VideoTrim.swift, update listFiles to scan both dirs
    status: completed
  - id: android-cache
    content: Add getCacheOutputPath to StorageUtil, migrate 5 headless APIs to cacheDir, update listFiles/deleteFile
    status: completed
  - id: readme-update
    content: Document utility functions and cache directory behavior in README.md
    status: completed
isProject: false
---

# Utility Functions and Cache Directory Migration

## Summary

Two changes:
1. **Three new utility functions** -- `saveToPhoto(path)`, `saveToDocuments(path)`, `share(path)` -- so users can compose any headless API output with save/share without duplicating options on every API.
2. **Move headless API outputs to cache directory** -- `getFrameAt`, `extractAudio`, `compress`, `toGif`, `merge` write to cache instead of documents/filesDir, since these are typically consumed immediately. Update `listFiles`/`cleanFiles` to scan both directories.

Existing `showEditor` and `trim` behavior is unchanged (they keep writing to documents/filesDir and keep their inline `saveToPhoto`/`openDocumentsOnFinish`/`openShareSheetOnFinish` options).

---

## Part 1: New Utility Functions

### TypeScript API

Add to [src/NativeVideoTrim.ts](src/NativeVideoTrim.ts):

```typescript
export interface SaveToPhotoResult {
  success: boolean;
}

export interface SaveToDocumentsResult {
  success: boolean;
}

export interface ShareResult {
  success: boolean;
}
```

Add to the `Spec` interface:

```typescript
saveToPhoto(filePath: string): Promise<SaveToPhotoResult>;
saveToDocuments(filePath: string): Promise<SaveToDocumentsResult>;
share(filePath: string): Promise<ShareResult>;
```

Add wrapper functions in [src/index.tsx](src/index.tsx):

```typescript
export function saveToPhoto(filePath: string): Promise<SaveToPhotoResult> { ... }
export function saveToDocuments(filePath: string): Promise<SaveToDocumentsResult> { ... }
export function share(filePath: string): Promise<ShareResult> { ... }
```

### iOS Implementation -- [ios/VideoTrim.swift](ios/VideoTrim.swift)

- Extract the existing `PHPhotoLibrary` save logic (currently inside the editor trim callback at ~line 524 and headless trim at ~line 726) into a new `public static func saveToPhoto(_ filePath:, completion:)` method.
- Extract `saveFileToFilesApp` (~line 846) into a `public static func saveToDocuments(_ filePath:, completion:)`.
- Extract `shareFile` (~line 857) into a `public static func share(_ filePath:, completion:)`. The standalone version should NOT call `self.closeEditor()` in the completion handler (unlike the current editor-embedded version).
- Add Old Arch `@objc` wrappers for all three, following the same pattern as `getFrameAt`/`extractAudio` etc.

### iOS Bridge -- [ios/VideoTrim.mm](ios/VideoTrim.mm)

- Add New Arch bridging methods for `saveToPhoto`, `saveToDocuments`, `share` (same pattern as existing methods -- convert args, call Swift static, resolve/reject).
- Add `RCT_EXTERN_METHOD` entries for Old Arch.

### Android Implementation -- [android/src/main/java/com/videotrim/BaseVideoTrimModule.kt](android/src/main/java/com/videotrim/BaseVideoTrimModule.kt)

- Add `fun saveToPhoto(filePath: String, promise: Promise)` -- reuses `StorageUtil.saveVideoToGallery`, resolves `{ success: true }` or rejects.
- Add `fun saveToDocuments(filePath: String, promise: Promise)` -- reuses the `saveFileToExternalStorage` Intent logic, resolves after activity result.
- Add `fun share(filePath: String, promise: Promise)` -- reuses the `shareFile` logic, resolves `{ success: true }`.

### Android Arch Modules

- [android/src/oldarch/VideoTrimSpec.kt](android/src/oldarch/VideoTrimSpec.kt) -- add 3 abstract methods.
- [android/src/oldarch/VideoTrimModule.kt](android/src/oldarch/VideoTrimModule.kt) -- add 3 `@ReactMethod` overrides.
- [android/src/newarch/VideoTrimModule.kt](android/src/newarch/VideoTrimModule.kt) -- add 3 override methods.

---

## Part 2: Cache Directory for Headless APIs

### iOS -- [ios/VideoTrim.swift](ios/VideoTrim.swift)

In each of the 5 headless static methods, change:
```swift
// Before
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
// After
let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
```

Affected methods: `getFrameAt`, `extractAudio`, `compress`, `toGif` (both palette and output), `merge` (both concat list and output).

Update `listFiles()` (~line 1088) to scan **both** documents and caches directories:
```swift
private static func listFiles() -> [URL] {
    var files: [URL] = []
    let dirs = [
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!,
    ]
    for dir in dirs {
        // ... scan for FILE_PREFIX as before
    }
    return files
}
```

Update `deleteFile(url:)` -- no change needed, it already accepts any URL.

### Android -- [android/src/main/java/com/videotrim/utils/StorageUtil.kt](android/src/main/java/com/videotrim/utils/StorageUtil.kt)

Add a cache-based output path helper:
```kotlin
fun getCacheOutputPath(context: Context, outputExt: String): String {
    val timestamp = System.currentTimeMillis() / 1000
    val file = File(context.cacheDir, "${VideoTrimmerUtil.FILE_PREFIX}_${timestamp}.$outputExt")
    return file.absolutePath
}
```

Update `listFiles` to scan both `filesDir` and `cacheDir`:
```kotlin
fun listFiles(context: Context): Array<String> {
    val dirs = listOf(context.filesDir, context.cacheDir)
    return dirs.flatMap { dir ->
        dir.listFiles { _, name -> name.startsWith(VideoTrimmerUtil.FILE_PREFIX) }?.toList() ?: emptyList()
    }.map { it.absolutePath }.toTypedArray()
}
```

Update `deleteFile(path: String?)` path validation to also allow `cacheDir`:
```kotlin
val allowedDirs = listOf(
    BaseUtils.getContext().filesDir.canonicalFile,
    BaseUtils.getContext().cacheDir.canonicalFile,
)
if (allowedDirs.none { file.path.startsWith(it.path) }) return false
```

### Android -- [android/src/main/java/com/videotrim/BaseVideoTrimModule.kt](android/src/main/java/com/videotrim/BaseVideoTrimModule.kt)

In `getFrameAt`: change `File(reactApplicationContext.filesDir, ...)` to `File(reactApplicationContext.cacheDir, ...)`.

In `extractAudio`, `compress`, `merge`: change `StorageUtil.getOutputPath(...)` to `StorageUtil.getCacheOutputPath(...)`.

In `toGif`: change `File(reactApplicationContext.filesDir, ...)` to `File(reactApplicationContext.cacheDir, ...)` for both palette and output files.

---

## Part 3: README Update

Add a section in [README.md](README.md) documenting:
- The three new utility functions with usage examples.
- A note that headless API outputs are written to the cache directory and may be purged by the OS under storage pressure.
- Recommend users call `deleteFile(outputPath)` after consuming the file, or `cleanFiles()` periodically.
