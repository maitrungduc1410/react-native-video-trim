---
description: "Fix common react-native-video-trim problems: linking errors, media that fails to load, millisecond durations, photo permissions, mp3 output and slow exports."
---

# Troubleshooting

## "The package doesn't seem to be linked"

The native module is missing from the build.

- iOS: run `npx pod-install ios`, then rebuild.
- Rebuild the app after installing or upgrading the package. A Metro reload does not load native code.
- Expo: use a development build or `npx expo run:ios` / `npx expo run:android`. Expo Go cannot load this library.

## The editor opens and closes, or shows "Fail to load media"

- Check the file with [`isValidFile()`](/guide/files#managing-outputs) first.
- For `https://` URLs, install the [`https` FFmpegKit package](/guide/remote-files) on both platforms and check the device's network.
- Some pickers return temporary URIs that expire. If you open the file later, copy it into your app's storage first.

## `maxDuration` does not seem to work

Durations are in **milliseconds**. `maxDuration: 30` means 30 ms; for 30 seconds use `30_000`. The editor never allows a selection shorter than 1 second, regardless of `minDuration`.

## `showEditor(uri)` throws

Always pass an options object, even an empty one: `showEditor(uri, {})`.

## The cut starts earlier or later than selected

Without precise trimming, cuts snap to keyframes. Set [`enablePreciseTrimming`](/guide/precise-trimming) to `true`.

## Saving to Photos fails

- iOS: add `NSPhotoLibraryUsageDescription` to `Info.plist`. Listen for `NO_PHOTO_PERMISSION` in [`onError`](/guide/errors).
- Android 9 and older: declare `WRITE_EXTERNAL_STORAGE` (see [Installation](/guide/installation#permissions)).

## `mp3` output fails

The default FFmpegKit builds do not include `libmp3lame`. Use `m4a` or `wav`, or switch to an FFmpegKit package that includes it.

## `merge()` or `mixAudio()` fails with a URL

Both only accept local files. Download the inputs first.

## Android: re-encoding fails on one specific device

The library already retries with HEVC and then software MPEG-4; see [Android encoder fallback](/guide/android-encoder-fallback). Collect the `onLog` output (or logcat with tag `VideoTrimmerUtil`) and include it when you open an issue.

## Android: share sheet conflicts with my FileProvider

The library uses its own provider (`${applicationId}.videotrimprovider`) and resource names, so it does not collide with yours. If you followed the docs for 8.2.1 or earlier, see the upgrade note in [Installation](/guide/installation#share-sheet).

## Build errors after changing SDK versions

Make sure the root `ext` values (`compileSdkVersion`, `minSdkVersion`, `targetSdkVersion`, `kotlinVersion`) match what your React Native version expects. The library uses them as described in [Installation](/guide/installation#sdk-and-ffmpeg-versions).

## Performance tips

- Use headless [`trim()`](/guide/headless#trim) for batch work without UI.
- Stream-copy trims are almost instant. Precise trimming, speed changes, transforms, `compress()` and `merge()` re-encode, so they take longer on large files.
- Delete outputs you no longer need, or call `cleanFiles()` periodically.
- Compress large videos before uploading them.

## Still stuck?

Search or open an issue on [GitHub](https://github.com/maitrungduc1410/react-native-video-trim/issues) with your platform, architecture, library version and the `onError` / `onLog` output.
