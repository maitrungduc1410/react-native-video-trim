---
name: Migrate Java to Kotlin
overview: Migrate all 7 Java files under `android/src/main/java/com/videotrim/` to Kotlin, creating `.kt` replacements and deleting the `.java` originals. The `iknow/` package is out of scope.
todos:
  - id: migrate-errorcode
    content: Migrate enums/ErrorCode.java to ErrorCode.kt
    status: completed
  - id: migrate-ivideotrimmer
    content: Migrate interfaces/IVideoTrimmerView.java to IVideoTrimmerView.kt
    status: completed
  - id: migrate-videotrimlistener
    content: Migrate interfaces/VideoTrimListener.java to VideoTrimListener.kt
    status: completed
  - id: migrate-mediametadatautil
    content: Migrate utils/MediaMetadataUtil.java to MediaMetadataUtil.kt
    status: completed
  - id: migrate-storageutil
    content: Migrate utils/StorageUtil.java to StorageUtil.kt
    status: completed
  - id: migrate-videotrimmerutil
    content: Migrate utils/VideoTrimmerUtil.java to VideoTrimmerUtil.kt
    status: completed
  - id: migrate-videotrimmerview
    content: Migrate widgets/VideoTrimmerView.java to VideoTrimmerView.kt
    status: completed
isProject: false
---

# Migrate Java to Kotlin

## Scope

7 Java files to migrate under `android/src/main/java/com/videotrim/`:

| File | Lines | Complexity |
|------|-------|-----------|
| `enums/ErrorCode.java` | 10 | Trivial -- simple enum |
| `interfaces/IVideoTrimmerView.java` | 5 | Trivial -- single-method interface |
| `interfaces/VideoTrimListener.java` | 19 | Simple -- interface with 9 methods |
| `utils/MediaMetadataUtil.java` | 93 | Medium -- static utility with thread + callback |
| `utils/StorageUtil.java` | 148 | Medium -- static utility with file I/O |
| `utils/VideoTrimmerUtil.java` | 172 | Medium -- static utility with FFmpeg + thumbnails |
| `widgets/VideoTrimmerView.java` | 1323 | Large -- full UI widget with touch, zoom, media |

**Out of scope:** `iknow/android/utils/` (user explicitly scoped to `com/videotrim` only). These remain as Java and are called from the Kotlin code without issue (Kotlin/Java interop is seamless).

**Already Kotlin:** `BaseVideoTrimModule.kt`, `VideoTrimPackage.kt` -- these import the Java classes; after migration they'll import the same Kotlin classes (same package, same names).

## Migration Strategy

For each file: create a new `.kt` file with idiomatic Kotlin, then delete the `.java` original. The order matters -- migrate dependencies first to avoid compilation issues:

1. **`ErrorCode.java`** -> `ErrorCode.kt` (no dependencies within scope)
2. **`IVideoTrimmerView.java`** -> `IVideoTrimmerView.kt` (no dependencies)
3. **`VideoTrimListener.java`** -> `VideoTrimListener.kt` (depends on `ErrorCode`)
4. **`MediaMetadataUtil.java`** -> `MediaMetadataUtil.kt` (depends on `StorageUtil`)
5. **`StorageUtil.java`** -> `StorageUtil.kt` (depends on `VideoTrimmerUtil.FILE_PREFIX`)
6. **`VideoTrimmerUtil.java`** -> `VideoTrimmerUtil.kt` (depends on `ErrorCode`, `VideoTrimListener`, `iknow` utils)
7. **`VideoTrimmerView.java`** -> `VideoTrimmerView.kt` (depends on everything above)

## Key Conversion Notes

- **Static methods** in Java utility classes -> Kotlin `object` with functions, or top-level functions, or `companion object`. Using `object` is cleanest since callers already use `ClassName.method()` syntax. Add `@JvmStatic` is NOT needed since all callers within `com/videotrim` will be Kotlin after migration. The `iknow/` Java code does not call these classes.
- **Java enums** -> Kotlin `enum class` (near-identical syntax)
- **Java interfaces** -> Kotlin `interface` (drop `public` modifier, it's default)
- **Nullable types**: Java code uses null checks; Kotlin migration uses `?` nullable types where appropriate
- **Anonymous inner classes** -> Kotlin lambdas or `object : Interface { }` as appropriate
- **`BackgroundExecutor.Task`** abstract class usage -> `object : BackgroundExecutor.Task(...) { override fun execute() { ... } }`
- **`VideoTrimmerView`**: largest file. Key patterns to convert:
  - `OnTouchListener` lambdas -> Kotlin lambda syntax (already partially used in Java)
  - `Handler` + `Runnable` -> same pattern in Kotlin
  - `GestureDetector.SimpleOnGestureListener` -> `object` expression
  - All `private` fields -> Kotlin properties
  - `view.setOnClickListener { }` already natural in Kotlin

## Interop Considerations

- The `iknow/android/utils/` Java classes (`BaseUtils`, `DeviceUtil`, `UnitConverter`, `BackgroundExecutor`, `SingleCallback`, `UiThreadExecutor`) remain Java. Kotlin calls Java seamlessly -- no issues.
- `BaseVideoTrimModule.kt` and `VideoTrimPackage.kt` already import the classes being migrated by their fully qualified names. Package names stay identical, class names stay identical -- no import changes needed.
- The `oldarch/VideoTrimModule.kt` and `newarch/VideoTrimModule.kt` also reference these classes -- same story, no changes needed.
- The Android `res/` XML files reference no Java classes directly (no custom views in XML that use fully qualified class names).
