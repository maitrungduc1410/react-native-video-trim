---
name: Fix merge different dimensions
overview: Add per-input scale/pad/format normalization filters before the concat filter so merge works with clips of different resolutions, pixel formats, and SARs.
todos:
  - id: ios-merge
    content: Update iOS merge filter_complex to normalize each input with scale/pad/setsar/format before concat
    status: completed
  - id: android-merge
    content: Update Android merge filter_complex with the same normalization approach
    status: completed
  - id: docs
    content: Update comments and README to document the dimension normalization behavior
    status: completed
isProject: false
---

# Fix merge() to handle clips with different dimensions

## Problem

The FFmpeg concat filter requires all inputs to have identical resolution, pixel format, and SAR. The current implementation feeds raw streams directly into `concat`, so merging clips with different dimensions (e.g. 1280x720 landscape + 828x1792 portrait) fails with:

```
Input link in0:v0 parameters (size 828x1792, SAR 0:1) do not match the corresponding output link in0:v0 parameters (1280x720, SAR 1:1)
```

## Solution

Insert `scale`, `pad`, `setsar`, and `format` filters for each input stream before they enter the concat filter. Use the **first clip's resolution** as the target dimensions.

### Current filter_complex (broken for different dimensions)

```
[0:v:0][0:a:0][1:v:0][1:a:0]concat=n=2:v=1:a=1[outv][outa]
```

### New filter_complex (normalizes all inputs)

```
[0:v:0]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p[v0];
[1:v:0]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p[v1];
[v0][0:a:0][v1][1:a:0]concat=n=2:v=1:a=1[outv][outa]
```

Each input gets:
- `scale=W:H:force_original_aspect_ratio=decrease` -- scale to fit within target, preserving aspect ratio
- `pad=W:H:(ow-iw)/2:(oh-ih)/2` -- center with black bars if aspect ratios differ
- `setsar=1` -- normalize sample aspect ratio
- `format=yuv420p` -- normalize pixel format

## Files to change

### iOS: [ios/VideoTrim.swift](ios/VideoTrim.swift) (merge function, ~line 1435)

- After probing bitrate in the existing loop, also read the first clip's video track dimensions via `AVURLAsset.tracks(withMediaType: .video).first.naturalSize` (applying `preferredTransform` for rotation)
- Build the filter_complex with per-input normalization filters instead of direct stream references:

```swift
// Determine target dimensions from first input
let firstURL = URL(string: urls[0]) ?? URL(fileURLWithPath: urls[0])
let firstAsset = AVURLAsset(url: firstURL)
var targetW = 1280; var targetH = 720
if let track = firstAsset.tracks(withMediaType: .video).first {
    let size = track.naturalSize.applying(track.preferredTransform)
    targetW = Int(abs(size.width))
    targetH = Int(abs(size.height))
}

// Build per-input scale+pad+format filters
let scaleFilter = "scale=\(targetW):\(targetH):force_original_aspect_ratio=decrease,pad=\(targetW):\(targetH):(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p"
var filterParts: [String] = []
for i in 0..<n {
    filterParts.append("[\(i):v:0]\(scaleFilter)[v\(i)]")
}
let concatInputs = (0..<n).map { "[v\($0)][\($0):a:0]" }.joined()
let filterComplex = filterParts.joined(separator: ";") + ";" + concatInputs + "concat=n=\(n):v=1:a=1[outv][outa]"
```

### Android: [android/src/main/java/com/videotrim/BaseVideoTrimModule.kt](android/src/main/java/com/videotrim/BaseVideoTrimModule.kt) (merge function, ~line 992)

- Same approach: read the first clip's width/height via `MediaMetadataRetriever` (already used for bitrate), then build the normalized filter_complex:

```kotlin
// Determine target dimensions from first input
var targetW = 1280; var targetH = 720
try {
    val retriever = MediaMetadataRetriever()
    retriever.setDataSource(reactApplicationContext, Uri.parse(urls.getString(0)))
    targetW = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 1280
    targetH = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 720
    retriever.release()
} catch (_: Exception) {}

val scaleFilter = "scale=$targetW:$targetH:force_original_aspect_ratio=decrease,pad=$targetW:$targetH:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p"
val scaleParts = (0 until n).joinToString(";") { "[$it:v:0]${scaleFilter}[v$it]" }
val concatInputs = (0 until n).joinToString("") { "[v$it][$it:a:0]" }
val filterComplex = "$scaleParts;${concatInputs}concat=n=$n:v=1:a=1[outv][outa]"
```

## Docs

- Update the merge comment in both files to note that different resolutions are now handled via scale+pad normalization using the first clip's dimensions
- Update README.md merge note to mention this behavior
