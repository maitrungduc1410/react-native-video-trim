# Table of Contents
- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  * [showEditor()](#showeditor)
  * [trim()](#trim)
  * [File Management](#file-management)
- [Configuration Options](#configuration-options)
  * [Basic Options](#basic-options)
  * [UI Customization](#ui-customization)
  * [Behavior Options](#behavior-options)
- [Platform Setup](#platform-setup)
- [Advanced Features](#advanced-features)
  * [Audio Trimming](#audio-trimming)
  * [Remote Files (HTTPS)](#remote-files-https)
  * [Video Rotation](#video-rotation)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

# React Native Video Trim

<div align="center">
  <h2>📱 Professional video trimmer for React Native apps</h2>
  
  <img src="images/android.gif" width="300" />
  <img src="images/ios.gif" width="300" />
  
  <p>
    <strong>✅ iOS & Android</strong> • 
    <strong>✅ New & Old Architecture</strong> • 
    <strong>✅ Expo Compatible</strong>
  </p>
</div>

## Overview

A powerful, easy-to-use video and audio trimming library for React Native applications.

### ✨ Key Features

- **📹 Video & Audio Support** - Trim both video and audio files
- **🌐 Local & Remote Files** - Support for local storage and HTTPS URLs
- **💾 Multiple Save Options** - Photos, Documents, or Share to other apps
- **✅ File Validation** - Built-in validation for media files
- **🗂️ File Management** - List, clean up, and delete specific files
- **🔄 Universal Architecture** - Works with both New and Old React Native architectures

### 🎛️ Core Capabilities

| Feature | Description |
|---------|-------------|
| **Trimming** | Precise video/audio trimming with visual controls |
| **Validation** | Check if files are valid video/audio before processing |
| **Save Options** | Photos, Documents, Share sheet integration |
| **File Management** | Complete file lifecycle management |
| **Customization** | Extensive UI and behavior customization |

<div align="center">
  <img src="images/document_picker.png" width="250" />
  <img src="images/share_sheet.png" width="250" />
</div>

## Installation

```bash
npm install react-native-video-trim
# or
yarn add react-native-video-trim
```

### Platform Setup

<details>
<summary><strong>📱 iOS Setup (React Native CLI)</strong></summary>

```bash
npx pod-install ios
```

**Permissions Required:**
- For saving to Photos: Add `NSPhotoLibraryUsageDescription` to `Info.plist`
</details>

<details>
<summary><strong>🤖 Android Setup (React Native CLI)</strong></summary>

**For New Architecture:**
```bash
cd android && ./gradlew generateCodegenArtifactsFromSchema
```

**Permissions Required:**
- For saving to Photos: Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

**For Share Sheet functionality**, add to `AndroidManifest.xml`:
```xml
<application>
  <!-- your other configs -->
  
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

Create `android/app/src/main/res/xml/file_paths.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
  <files-path name="internal_files" path="." />
  <external-path name="external_files" path="." />
</paths>
```
</details>

<details>
<summary><strong>🔧 Expo Setup</strong></summary>

```bash
npx expo prebuild
```

Then rebuild your app. **Note:** Expo Go may not work due to native dependencies - use development builds or `expo run:ios`/`expo run:android`.
</details>

## Quick Start

Get up and running in 3 simple steps:

```javascript
import { showEditor } from 'react-native-video-trim';

// 1. Basic usage - open video editor
showEditor(videoUrl);

// 2. With duration limit
showEditor(videoUrl, {
  maxDuration: 20,
});

// 3. With save options
showEditor(videoUrl, {
  maxDuration: 30,
  saveToPhoto: true,
  openShareSheetOnFinish: true,
});
```

### Complete Example with File Picker

```javascript
import { showEditor } from 'react-native-video-trim';
import { launchImageLibrary } from 'react-native-image-picker';

const trimVideo = () => {
  // Pick a video
  launchImageLibrary({ mediaType: 'video' }, (response) => {
    if (response.assets && response.assets[0]) {
      const videoUri = response.assets[0].uri;
      
      // Open editor
      showEditor(videoUri, {
        maxDuration: 60, // 60 seconds max
        saveToPhoto: true,
      });
    }
  });
};
```

> 💡 **More Examples:** Check the [example folder](./example/src/) for complete implementation details with event listeners for both New and Old architectures.

## API Reference

### showEditor()

Opens the video trimmer interface.

```typescript
showEditor(videoPath: string, config?: EditorConfig): void
```

**Parameters:**
- `videoPath` (string): Path to video file (local or remote HTTPS URL)
- `config` (EditorConfig, optional): Configuration options (see [Configuration Options](#configuration-options))

**Example:**
```javascript
showEditor('/path/to/video.mp4', {
  maxDuration: 30,
  saveToPhoto: true,
});
```

### trim()

Programmatically trim a video without showing the UI.

```typescript
trim(url: string, options: TrimOptions): Promise<string>
```

**Returns:** Promise resolving to the output file path

**Example:**
```javascript
const outputPath = await trim('/path/to/video.mp4', {
  startTime: 5000,  // 5 seconds
  endTime: 25000,   // 25 seconds
});
```

### File Management

| Method | Description | Returns |
|--------|-------------|---------|
| `isValidFile(videoPath)` | Check if file is valid video/audio | `Promise<boolean>` |
| `listFiles()` | List all generated output files | `Promise<string[]>` |
| `cleanFiles()` | Delete all generated files | `Promise<number>` |
| `deleteFile(filePath)` | Delete specific file | `Promise<boolean>` |
| `closeEditor()` | Close the editor interface | `void` |

**Examples:**
```javascript
// Validate file before processing
const isValid = await isValidFile('/path/to/video.mp4');
if (!isValid) {
  console.log('Invalid video file');
  return;
}

// Clean up generated files
const deletedCount = await cleanFiles();
console.log(`Deleted ${deletedCount} files`);
```

## Configuration Options

All configuration options are optional. Here are the most commonly used ones:

### Basic Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `type` | `'video' \| 'audio'` | `'video'` | Media type to trim |
| `outputExt` | `string` | `'mp4'` | Output file extension |
| `maxDuration` | `number` | - | Maximum duration in milliseconds |
| `minDuration` | `number` | `1000` | Minimum duration in milliseconds |
| `autoplay` | `boolean` | `false` | Auto-play media on load |
| `jumpToPositionOnLoad` | `number` | - | Initial position in milliseconds |

### Save & Share Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `saveToPhoto` | `boolean` | `false` | Save to photo gallery (requires permissions) |
| `openDocumentsOnFinish` | `boolean` | `false` | Open document picker when done |
| `openShareSheetOnFinish` | `boolean` | `false` | Open share sheet when done |
| `removeAfterSavedToPhoto` | `boolean` | `false` | Delete file after saving to photos |
| `removeAfterShared` | `boolean` | `false` | Delete file after sharing (iOS only) |

### UI Customization

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `cancelButtonText` | `string` | `"Cancel"` | Cancel button text |
| `saveButtonText` | `string` | `"Save"` | Save button text |
| `trimmingText` | `string` | `"Trimming video..."` | Progress dialog text |
| `headerText` | `string` | - | Header text |
| `headerTextSize` | `number` | `16` | Header text size |
| `headerTextColor` | `string` | `"white"` | Header text color |
| `trimmerColor` | `string` | - | Trimmer bar color |
| `handleIconColor` | `string` | - | Trimmer handle color |
| `fullScreenModalIOS` | `boolean` | `false` | Use fullscreen modal on iOS |

### Advanced Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enableHapticFeedback` | `boolean` | `true` | Enable haptic feedback |
| `closeWhenFinish` | `boolean` | `true` | Close editor when done |
| `enableRotation` | `boolean` | `false` | Enable video rotation |
| `rotationAngle` | `number` | `0` | Rotation angle in degrees |
| `changeStatusBarColorOnOpen` | `boolean` | `false` | Change status bar color (Android) |
| `alertOnFailToLoad` | `boolean` | `true` | Show alert on load failure |

### Example Configuration

```javascript
showEditor(videoPath, {
  // Basic settings
  maxDuration: 60000,
  minDuration: 3000,
  
  // Save options
  saveToPhoto: true,
  openShareSheetOnFinish: true,
  removeAfterSavedToPhoto: true,
  
  // UI customization
  headerText: "Trim Your Video",
  cancelButtonText: "Back",
  saveButtonText: "Done",
  trimmerColor: "#007AFF",
  
  // Behavior
  autoplay: true,
  enableCancelTrimming: true,
});
```

## Platform Setup

### Android SDK Customization

You can override SDK versions in `android/build.gradle`:

```gradle
buildscript {
    ext {
        VideoTrim_kotlinVersion = '2.0.21'
        VideoTrim_minSdkVersion = 24
        VideoTrim_targetSdkVersion = 34
        VideoTrim_compileSdkVersion = 35
        VideoTrim_ndkVersion = '27.1.12297006'
    }
}
```

## Advanced Features

### Audio Trimming

<div align="center">
  <img src="images/audio_android.jpg" width="200" />
  <img src="images/audio_ios.jpg" width="200" />
</div>

For audio-only trimming, specify the media type and output format:

```javascript
showEditor(audioUrl, {
  type: 'audio',        // Enable audio mode
  outputExt: 'wav',     // Output format (mp3, wav, m4a, etc.)
  maxDuration: 30000,   // 30 seconds max
});
```

### Remote Files (HTTPS)

To trim remote files, you need the HTTPS-enabled version of FFmpeg:

**Android:**
```gradle
// android/build.gradle
buildscript {
    ext {
        VideoTrim_ffmpeg_package = 'https'
        // Optional: VideoTrim_ffmpeg_version = '6.0.1'
    }
}
```

**iOS:**
```bash
FFMPEGKIT_PACKAGE=https FFMPEG_KIT_PACKAGE_VERSION=6.0 pod install
```

**Usage:**
```javascript
showEditor('https://example.com/video.mp4', {
  maxDuration: 60000,
});
```

### Video Rotation

Rotate videos during trimming using metadata (doesn't re-encode):

```javascript
showEditor(videoUrl, {
  enableRotation: true,
  rotationAngle: 90,    // 90, 180, 270 degrees
});
```

**Note:** Uses `display_rotation` metadata - playback may vary by platform/player.

### Trimming Progress & Cancellation

<div align="center">
  <img src="images/progress.jpg" width="200" />
  <img src="images/cancel_confirm.jpg" width="200" />
</div>

Users can cancel trimming while in progress:

```javascript
showEditor(videoUrl, {
  enableCancelTrimming: true,
  cancelTrimmingButtonText: "Stop",
  trimmingText: "Processing video...",
});
```

### Error Handling

<img src="images/fail_to_load_media.jpg" width="200" />

Handle loading errors gracefully:

```javascript
showEditor(videoUrl, {
  alertOnFailToLoad: true,
  alertOnFailTitle: "Oops!",
  alertOnFailMessage: "Cannot load this video file",
  alertOnFailCloseText: "OK",
});
```

## Examples

### Complete Implementation (New Architecture)

```javascript
import React, { useEffect, useRef } from 'react';
import { TouchableOpacity, Text, View } from 'react-native';
import { showEditor, isValidFile, type Spec } from 'react-native-video-trim';
import { launchImageLibrary } from 'react-native-image-picker';

export default function VideoTrimmer() {
  const listeners = useRef({});

  useEffect(() => {
    // Set up event listeners
    listeners.current.onFinishTrimming = (NativeVideoTrim as Spec)
      .onFinishTrimming(({ outputPath, startTime, endTime, duration }) => {
        console.log('Trimming completed:', {
          outputPath,
          startTime,
          endTime,
          duration
        });
      });

    listeners.current.onError = (NativeVideoTrim as Spec)
      .onError(({ message, errorCode }) => {
        console.error('Trimming error:', message, errorCode);
      });

    return () => {
      // Cleanup listeners
      Object.values(listeners.current).forEach(listener => 
        listener?.remove()
      );
    };
  }, []);

  const selectAndTrimVideo = async () => {
    const result = await launchImageLibrary({
      mediaType: 'video',
      quality: 1,
    });

    if (result.assets?.[0]?.uri) {
      const videoUri = result.assets[0].uri;
      
      // Validate file first
      const isValid = await isValidFile(videoUri);
      if (!isValid) {
        console.log('Invalid video file');
        return;
      }

      // Open editor
      showEditor(videoUri, {
        maxDuration: 60000,        // 1 minute max
        saveToPhoto: true,         // Save to gallery
        openShareSheetOnFinish: true,
        headerText: "Trim Video",
        trimmerColor: "#007AFF",
      });
    }
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <TouchableOpacity 
        onPress={selectAndTrimVideo}
        style={{ 
          backgroundColor: '#007AFF', 
          padding: 15, 
          borderRadius: 8 
        }}
      >
        <Text style={{ color: 'white', fontSize: 16 }}>
          Select & Trim Video
        </Text>
      </TouchableOpacity>
    </View>
  );
}
```

### Old Architecture Implementation

```javascript
import React, { useEffect } from 'react';
import { NativeEventEmitter, NativeModules } from 'react-native';
import { showEditor } from 'react-native-video-trim';

export default function VideoTrimmer() {
  useEffect(() => {
    const eventEmitter = new NativeEventEmitter(NativeModules.VideoTrim);
    
    const subscription = eventEmitter.addListener('VideoTrim', (event) => {
      switch (event.name) {
        case 'onFinishTrimming':
          console.log('Video trimmed:', event.outputPath);
          break;
        case 'onError':
          console.error('Trimming failed:', event.message);
          break;
        // Handle other events...
      }
    });

    return () => subscription.remove();
  }, []);

  // Rest of implementation...
}
```

## Troubleshooting

### Common Issues

**Android Build Errors:**
- Ensure `file_paths.xml` exists for share functionality
- Check SDK versions match your project requirements
- Verify permissions in `AndroidManifest.xml`

**iOS Build Errors:**
- Run `pod install` after installation
- Check Info.plist permissions for photo access
- Use development builds with Expo (not Expo Go)

**Runtime Issues:**
- Validate files with `isValidFile()` before processing
- Use HTTPS version for remote files
- Check network connectivity for remote files
- Ensure proper permissions for save operations

### Performance Tips

- Use `trim()` for batch processing without UI
- Clean up generated files regularly with `cleanFiles()`
- Consider file compression for large videos
- Use appropriate `maxDuration` limits

## Credits

- **Android:** Based on [Android-Video-Trimmer](https://github.com/iknow4/Android-Video-Trimmer)
- **iOS:** UI from [VideoTrimmerControl](https://github.com/AndreasVerhoeven/VideoTrimmerControl)