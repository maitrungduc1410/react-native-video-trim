# React Native Video Trim
<div align="center">
<h2>Video trimmer for your React Native app</h2>

<img src="images/android.gif" width="300" />
<img src="images/ios.gif" width="300" />
</div>

## Installation

```sh
npm install react-native-video-trim

# or with yarn

yarn add react-native-video-trim
```
Next install CocoaPods deps:

```
npx pod-install ios
```

## Usage
>  Note that for iOS you have to try on real device

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

```tsx
import * as React from 'react';

import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  NativeEventEmitter,
  NativeModules,
} from 'react-native';
import { isValidVideo, showEditor } from 'react-native-video-trim';
import { launchImageLibrary } from 'react-native-image-picker';
import { useEffect } from 'react';

export default function App() {
  useEffect(() => {
    const eventEmitter = new NativeEventEmitter(NativeModules.VideoTrim);
    const subscription = eventEmitter.addListener('VideoTrim', (event) => {
      switch (event.name) {
        case 'onShow': {
          console.log('onShowListener', event);
          break;
        }
        case 'onHide': {
          console.log('onHide', event);
          break;
        }
        case 'onStartTrimming': {
          console.log('onStartTrimming', event);
          break;
        }
        case 'onFinishTrimming': {
          console.log('onFinishTrimming', event);
          break;
        }
        case 'onCancelTrimming': {
          console.log('onCancelTrimming', event);
          break;
        }
        case 'onError': {
          console.log('onError', event);
          break;
        }
      }
    });

    return () => {
      subscription.remove();
    };
  }, []);

  return (
    <View style={styles.container}>
      <TouchableOpacity
        onPress={async () => {
          const result = await launchImageLibrary({
            mediaType: 'video',
            assetRepresentationMode: 'current',
          });

          isValidVideo(result.assets![0]?.uri || '').then((res) =>
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
          isValidVideo('invalid file path').then((res) => console.log(res));
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

## showEditor(videoPath: string, config?: EditorConfig)
Main method to show Video Editor UI.

*Params*:
- `videoPath`: Path to video file, if this is an invalid path, `onError` event will be fired
- `config` (optional): 

  - `saveToPhoto` (optional, `default = true`): whether to save video to photo/gallery after editing
  - `removeAfterSavedToPhoto` (optional, `default = false`): whether to remove output file from storage after saved to Photo
  - `maxDuration` (optional): maximum duration for the trimmed video
  - `cancelButtonText` (optional): text of left button in Editor dialog
  - `saveButtonText` (optional): text of right button in Editor dialog
  -  `enableCancelDialog` (optional, `default = true`): whether to show alert dialog on press Cancel
  -  `cancelDialogTitle` (optional, `default = "Warning!"`)
  -  `cancelDialogMessage` (optional, `default = "Are you sure want to cancel?"`)
  -  `cancelDialogCancelText` (optional, `default = "Close"`)
  -  `cancelDialogConfirmText` (optional, `default = "Proceed"`)
  -  `enableSaveDialog` (optional, `default = true`): whether to show alert dialog on press Save
  -  `saveDialogTitle` (optional, `default = "Confirmation!"`)
  -  `saveDialogMessage` (optional, `default = "Are you sure want to save?"`)
  -  `saveDialogCancelText` (optional, `default = "Close"`)
  -  `saveDialogConfirmText` (optional, `default = "Proceed"`)
  -  `trimmingText` (optional, `default = "Trimming video..."`): trimming text on the progress dialog

If `saveToPhoto = true`, you must ensure that you have request permission to write to photo/gallery
- For Android: you need to have `<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />` in AndroidManifest.xml
- For iOS: you need `NSPhotoLibraryUsageDescription` in Info.plist

## isValidVideo(videoPath: string)

This method is to check if a path is a actual video and editable. It returns `Promise<boolean>`

## listFiles()
Return array of generated output files in app storage. (`Promise<string[]>`)

## cleanFiles()
Clean all generated output files in app storage. Return number of successfully deleted files (`Promise<number>`)

## deleteFile()
Delete a file in app storage. Return `true` if success

# Events
To listen for events you interest, do the following:
```js
useEffect(() => {
  const eventEmitter = new NativeEventEmitter(NativeModules.VideoTrim);
  const subscription = eventEmitter.addListener('VideoTrim', (event) => {
    switch (event.name) {
      case 'onShow': {
        // on Dialog show
        console.log('onShowListener', event);
        break;
      }
      case 'onHide': {
        // on Dialog hide
        console.log('onHide', event);
        break;
      }
      case 'onStartTrimming': {
        // on start trimming
        console.log('onStartTrimming', event);
        break;
      }
      case 'onFinishTrimming': {
        // on trimming is done
        console.log('onFinishTrimming', event);
        break;
      }
      case 'onCancelTrimming': {
        // when user clicks Cancel button
        console.log('onCancelTrimming', event);
        break;
      }
      case 'onError': {
        // any error occured: invalid file, lack of permissions to write to photo/gallery, unexpected error...
        console.log('onError', event);
        break;
      }
    }
  });

  return () => {
    subscription.remove();
  };
}, []);
```
# FFMPEG Version
This library uses FFMPEG-Kit Android under the hood, by default FFMPEG-min is used, which gives smallest bundle size: https://github.com/arthenica/ffmpeg-kit#9-packages

If you ever need to use other version of FFMPEG-Kit for Android, you can do the following, in your `android/build.gradle` > `buildscript` > `ext`:

```gradle
buildscript {
    ext {
        ffmpegKitPackage = "full" // default "min", if followed by lts then LTS version is use. Eg "full-lts"

        ffmpegKitPackageVersion = "5.1.LTS" // use exact version, highest precedence, default 6.0-2 if ignored
    }
```
# Thanks
- Android part is created by modified + fix bugs from: https://github.com/iknow4/Android-Video-Trimmer
- iOS UI is created from: https://github.com/AndreasVerhoeven/VideoTrimmerControl