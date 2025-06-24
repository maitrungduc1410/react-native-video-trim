# Table of contents
- [Installation](#installation)
   * [For iOS (React Native CLI project)](#for-ios-react-native-cli-project)
   * [For Expo project](#for-expo-project)
   * [Usage](#usage)
- [Methods](#methods)
   * [showEditor(videoPath: string, config?: EditorConfig) => void)](#showeditorvideopath-string-config-editorconfig--void)
   * [trim(url: string, options: TrimOptions): Promise<string>](#trimurl-string-options-trimoptions-promise)
   * [isValidFile(videoPath: string)](#isvalidfilevideopath-string)
   * [closeEditor()](#closeeditor)
   * [listFiles()](#listfiles)
   * [cleanFiles()](#cleanfiles)
   * [deleteFile()](#deletefile)
- [Callbacks (New arch)](#callbacks-new-arch)
   * [showEditor](#showeditor)
   * [closeEditor](#closeeditor-1)
- [Audio support](#audio-support)
- [Cancel trimming](#cancel-trimming)
- [Fail to load media](#fail-to-load-media)
- [Rotation](#rotation)
- [Use FFMPEG HTTPS version](#use-ffmpeg-https-version)
- [Android: update SDK version](#android-update-sdk-version)
- [Thanks](#thanks)

# React Native Video Trim
<div align="center">
<h2>Video trimmer for your React Native app</h2>

<img src="images/android.gif" width="300" />
<img src="images/ios.gif" width="300" />
</div>

## Features
- ✅ Support video and audio
- ✅ Support local files and remote files (remote files need `https` version, see below)
- ✅ Save to Photos, Documents and Share to other apps
- ✅ Check if file is valid video/audio
- ✅ File operations: list, clean up, delete specific file
- ✅ Support React Native New + Old Arch

<div align="left">
<img src="images/document_picker.png" width="300" />
<img src="images/share_sheet.png" width="300" />
</div>

# Installation

```sh
# new arch
npm install react-native-video-trim

# old arch
npm install react-native-video-trim@^3.0.0

# or with yarn

# new arch
yarn add react-native-video-trim

# old arch
yarn add react-native-video-trim@^3.0.0
```

## For iOS (React Native CLI project)
Run the following command to setup for iOS:
```
npx pod-install ios
```
## For Expo project
You need to run `prebuild` in order for native code takes effect:
```
npx expo prebuild
```
Then you need to restart to make the changes take effect

> Note that on iOS you'll need to run on real device, Expo Go may not work because of library linking

## Usage

```js
import { showEditor } from 'react-native-video-trim';

// ...

showEditor(videoUrl);

// or with output length limit

showEditor(videoUrl, {
  maxDuration: 20,
});
```
Usually this library will be used along with other library to select video file, Eg. [react-native-image-picker](https://github.com/react-native-image-picker/react-native-image-picker). Below is real world example:

```jsx
import * as React from 'react';

import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  NativeEventEmitter,
  NativeModules,
  type EventSubscription,
} from 'react-native';
import { isValidFile, showEditor } from 'react-native-video-trim';
import { launchImageLibrary } from 'react-native-image-picker';

export default function App() {
  const listenerSubscription = useRef<Record<string, EventSubscription>>({});

  useEffect(() => {
    listenerSubscription.current.onLoad = NativeVideoTrim.onLoad(
      ({ duration }) => console.log('onLoad', duration)
    );

    listenerSubscription.current.onStartTrimming =
      NativeVideoTrim.onStartTrimming(() => console.log('onStartTrimming'));

    listenerSubscription.current.onCancelTrimming =
      NativeVideoTrim.onCancelTrimming(() => console.log('onCancelTrimming'));
    listenerSubscription.current.onCancel = NativeVideoTrim.onCancel(() =>
      console.log('onCancel')
    );
    listenerSubscription.current.onHide = NativeVideoTrim.onHide(() =>
      console.log('onHide')
    );
    listenerSubscription.current.onShow = NativeVideoTrim.onShow(() =>
      console.log('onShow')
    );
    listenerSubscription.current.onFinishTrimming =
      NativeVideoTrim.onFinishTrimming(
        ({ outputPath, startTime, endTime, duration }) =>
          console.log(
            'onFinishTrimming',
            `outputPath: ${outputPath}, startTime: ${startTime}, endTime: ${endTime}, duration: ${duration}`
          )
      );
    listenerSubscription.current.onLog = NativeVideoTrim.onLog(
      ({ level, message, sessionId }) =>
        console.log(
          'onLog',
          `level: ${level}, message: ${message}, sessionId: ${sessionId}`
        )
    );
    listenerSubscription.current.onStatistics = NativeVideoTrim.onStatistics(
      ({
        sessionId,
        videoFrameNumber,
        videoFps,
        videoQuality,
        size,
        time,
        bitrate,
        speed,
      }) =>
        console.log(
          'onStatistics',
          `sessionId: ${sessionId}, videoFrameNumber: ${videoFrameNumber}, videoFps: ${videoFps}, videoQuality: ${videoQuality}, size: ${size}, time: ${time}, bitrate: ${bitrate}, speed: ${speed}`
        )
    );
    listenerSubscription.current.onError = NativeVideoTrim.onError(
      ({ message, errorCode }) =>
        console.log('onError', `message: ${message}, errorCode: ${errorCode}`)
    );

    return () => {
      listenerSubscription.current.onLoad?.remove();
      listenerSubscription.current.onStartTrimming?.remove();
      listenerSubscription.current.onCancelTrimming?.remove();
      listenerSubscription.current.onCancel?.remove();
      listenerSubscription.current.onHide?.remove();
      listenerSubscription.current.onShow?.remove();
      listenerSubscription.current.onFinishTrimming?.remove();
      listenerSubscription.current.onLog?.remove();
      listenerSubscription.current.onStatistics?.remove();
      listenerSubscription.current.onError?.remove();
      listenerSubscription.current = {};
    };
  });

  return (
    <View style={styles.container}>
      <TouchableOpacity
        onPress={async () => {
          const result = await launchImageLibrary({
            mediaType: 'video',
            assetRepresentationMode: 'current',
          });

          isValidFile(result.assets![0]?.uri || '').then((res) =>
            console.log(res)
          );

          showEditor(result.assets![0]?.uri || '', {
            maxDuration: 20,
          });
        }}
        style={{ padding: 10, backgroundColor: 'red' }}
      >
        <Text>Launch Library</Text>
      </TouchableOpacity>
      <TouchableOpacity
        onPress={() => {
          isValidFile('invalid file path').then((res) => console.log(res));
        }}
        style={{
          padding: 10,
          backgroundColor: 'blue',
          marginTop: 20,
        }}
      >
        <Text>Check Video Valid</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
```

# Methods

## showEditor(videoPath: string, config?: EditorConfig) => void)
Main method to show Video Editor UI.

*Params*:
- `videoPath`: Path to video file, if this is an invalid path, `onError` event will be fired
- `config` (optional, every sub props of `config` is optional): 
  
  - `type` (`default = video`): which player to use, `video` or `audio`
  - `outputExt` (`default = mp4`): output file extension
  - `enableHapticFeedback` (`default = true`): whether to enable haptic feedback
  - `saveToPhoto` (Video-only, `default = false`): whether to save video to photo/gallery after editing
  - `openDocumentsOnFinish` (`default = false`): open Document Picker on done trimming
  - `openShareSheetOnFinish` (`default = false`): open Share Sheet on done trimming
  - `removeAfterSavedToPhoto` (`default = false`): whether to remove output file from storage after saved to Photo successfully
  - `removeAfterFailedToSavePhoto` (`default = false`): whether to remove output file if fail to save to Photo
  - `removeAfterSavedToDocuments` (`default = false`): whether to remove output file from storage after saved Documents successfully
  - `removeAfterFailedToSaveDocuments` (`default = false`): whether to remove output file from storage after fail to save to Documents
  - `removeAfterShared` (`default = false`): whether to remove output file from storage after saved Share successfully. iOS only, on Android you'll have to manually remove the file (this is because on Android there's no way to detect when sharing is successful)
  - `removeAfterFailedToShare` (`default = false`): whether to remove output file from storage after fail to Share. iOS only, on Android you'll have to manually remove the file
  - `maxDuration` (optional): maximum duration for the trimmed video
  - `minDuration` (`default = 1000`): minimum duration for the trimmed video
  - `cancelButtonText` (`default= "Cancel"`): text of left button in Editor dialog
  - `saveButtonText` (`default= "Save"`): text of right button in Editor dialog
  - `enableCancelDialog` (`default = true`): whether to show alert dialog on press Cancel
  - `cancelDialogTitle` (`default = "Warning!"`)
  - `cancelDialogMessage` (`default = "Are you sure want to cancel?"`)
  - `cancelDialogCancelText` (`default = "Close"`)
  - `cancelDialogConfirmText` (`default = "Proceed"`)
  - `enableSaveDialog` (`default = true`): whether to show alert dialog on press Save
  - `saveDialogTitle` (`default = "Confirmation!"`)
  - `saveDialogMessage` (`default = "Are you sure want to save?"`)
  - `saveDialogCancelText` (`default = "Close"`)
  - `saveDialogConfirmText` (`default = "Proceed"`)
  - `fullScreenModalIOS` (`default = false`): whether to open editor in fullscreen modal
  - `trimmingText` (`default = "Trimming video..."`): trimming text on the progress dialog
  - `autoplay` (`default = false`): whether to autoplay media on load
  - `jumpToPositionOnLoad` (optional): which time position should jump on media loaded (millisecond)
  - `closeWhenFinish` (`default = true`): should editor close on finish trimming
  - `enableCancelTrimming` (`default = true`): enable cancel trimming
  - `cancelTrimmingButtonText` (`default = "Cancel"`)
  - `enableCancelTrimmingDialog` (`default = true`)
  - `cancelTrimmingDialogTitle` (`default = "Warning!"`)
  - `cancelTrimmingDialogMessage` (`default = "Are you sure want to cancel trimming?"`)
  - `cancelTrimmingDialogCancelText` (`default = "Close"`)
  - `cancelTrimmingDialogConfirmText` (`default = "Proceed"`)
  - `headerText` (optional)
  - `headerTextSize` (`default = 16`)
  - `headerTextColor` (`default = white`)
  - `alertOnFailToLoad` (`default = true`)
  - `alertOnFailTitle` (`default = "Error"`)
  - `alertOnFailMessage` (`default = "Fail to load media. Possibly invalid file or no network connection"`)
  - `alertOnFailCloseText` (`default = "Close"`)
  - `enableRotation` (`default = false`)
  - `rotationAngle` (`default = 0`)

If `saveToPhoto = true`, you must ensure that you have request permission to write to photo/gallery
- For Android: you need to have `<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />` in AndroidManifest.xml
- For iOS: you need `NSPhotoLibraryUsageDescription` in Info.plist

If `openShareSheetOnFinish=true`, on Android you'll need to update `AndroidManifest.xml` like below:
```xml
</application>
  ...
  <provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.provider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
      android:name="android.support.FILE_PROVIDER_PATHS"
      android:resource="@xml/file_paths" />
  </provider>
</application>
```

If you face issue when building Android app related to `file_paths`, then you may need to create `res/xml/file_paths.xml`: with the following content:
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
  <files-path name="internal_files" path="." />
  <external-path name="external_files" path="." />
</paths>
```

## trim(url: string, options: TrimOptions): Promise<string>

Directly trim a file without showing editor

## isValidFile(videoPath: string)

This method is to check if a path is a valid video/audio

## closeEditor()

Close Editor

## listFiles()
Return array of generated output files in app storage. (`Promise<string[]>`)

## cleanFiles()
Clean all generated output files in app storage. Return number of successfully deleted files (`Promise<number>`)

## deleteFile()
Delete a file in app storage. Return `true` if success

# Callbacks (New arch)

## showEditor

```ts
showEditor('file', config)
```

## closeEditor

```ts
closeEditor()
```

# Audio support
<div align="left">
<img src="images/audio_android.jpg" width="200" />
<img src="images/audio_ios.jpg" width="200" />
</div>

For audio only you have to pass `type=audio` and `outputExt`:
```ts
showEditor(url, {
  type: 'audio', // important
  outputExt: 'wav', // important: any audio type for output file extension
})
```

# Cancel trimming
<div align="left">
<img src="images/progress.jpg" width="200" />
<img src="images/cancel_confirm.jpg" width="200" />
</div>

While trimming, you can press Cancel to terminate the process.

Related props: `enableCancelTrimming, cancelTrimmingButtonText, enableCancelTrimmingDialog, cancelTrimmingDialogTitle, cancelTrimmingDialogMessage, cancelTrimmingDialogCancelText, cancelTrimmingDialogConfirmText`

# Fail to load media
<img src="images/fail_to_load_media.jpg" width="200" />

If there's error while loading media, there'll be a prompt

Related props: `alertOnFailToLoad, alertOnFailTitle, alertOnFailMessage, alertOnFailCloseText`

# Rotation

To trim & rotate video you can pass `enableRotation` and `rotationAngle` to `showEditor`/`trim`. But note that it doesn't re-encode the video, instead the lib uses `display_rotation` metadata from ffmpeg, and some players/platforms may show differently.

# Use FFMPEG HTTPS version

If you want to trim a remote file, you need to use `https` version (default is `min` which does not support remote file).

Do the following:

```
// android/build.gradle
buildscript {
    ext {
        VideoTrim_ffmpeg_package=https

        // optional: VideoTrim_ffmpeg_version=6.0.1
    }
}

// ios
FFMPEGKIT_PACKAGE=https FFMPEG_KIT_PACKAGE_VERSION=6.0 pod install
```

# Android: update SDK version
You can override sdk version to use any version in your `android/build.gradle` > `buildscript` > `ext`
```gradle
buildscript {
    ext {
        VideoTrim_kotlinVersion=2.0.21
        VideoTrim_minSdkVersion=24
        VideoTrim_targetSdkVersion=34
        VideoTrim_compileSdkVersion=35
        VideoTrim_ndkVersion=27.1.12297006
    }
}
```

# Thanks
- Android part is created by modified + fix bugs from: https://github.com/iknow4/Android-Video-Trimmer
- iOS UI is created from: https://github.com/AndreasVerhoeven/VideoTrimmerControl