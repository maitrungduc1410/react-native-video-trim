# React Native Video Trim - AI Coding Instructions

## Architecture Overview

This is a **dual-architecture React Native library** that supports both Old and New React Native architectures. The core pattern is:

- **`src/index.tsx`** - Main entry point with fabric detection: `const isFabric = !!(global as any).nativeFabricUIManager`
- **`src/NativeVideoTrim.ts`** - TurboModule spec for New Architecture (Fabric)
- **`src/OldArch.ts`** - Legacy bridge module for Old Architecture
- **Platform-specific implementations**: iOS (Swift) and Android (Kotlin) with shared base classes

## Key Components & Data Flow

### Native Bridge Pattern
```typescript
// Architecture selection happens at runtime
const VideoTrim = isFabric ? VideoTrimNewArch : VideoTrimOldArch;
```

### Platform Implementation Strategy
- **iOS**: `BaseVideoTrimModule.swift` → `VideoTrimmerViewController.swift` (UI) → FFMpegKit processing  
- **Android**: `BaseVideoTrimModule.kt` → composition pattern with separate `oldarch/` and `newarch/` modules
- **Event System**: Both platforms use identical event names (`onStartTrimming`, `onFinishTrimming`, etc.)

### File Structure Logic
```
src/                    # TypeScript interfaces & architecture detection
ios/                    # Swift implementation using AVFoundation + FFMpegKit
android/src/main/       # Base Kotlin classes
android/src/oldarch/    # Old Architecture module (ReactModule)
android/src/newarch/    # New Architecture module (TurboModule events)
```

## Development Patterns

### Adding New Features
1. **Define TypeScript interface** in `NativeVideoTrim.ts` (extend `Spec` interface)
2. **Implement in base classes**: `ios/VideoTrim.swift` and `android/.../BaseVideoTrimModule.kt`
3. **Handle events** in both `oldarch/VideoTrimModule.kt` and `newarch/VideoTrimModule.kt`
4. **Export from main entry** in `src/index.tsx` with helper functions

### Configuration Objects Pattern
The library uses factory functions for consistent defaults:
```typescript
// Always use these helpers to ensure proper defaults
createBaseOptions(overrides)     // Base configuration
createEditorConfig(overrides)    # UI editor configuration
```

### Event Handling Architecture
Both platforms emit identical events that flow through architecture-specific bridges:
- **Old Arch**: `DeviceEventManagerModule.RCTDeviceEventEmitter.emit()`
- **New Arch**: Direct TurboModule event emission (`emitOnStartTrimming()`, etc.)

## Critical Build & Development Commands

### Monorepo Management
```bash
# Work with example app (uses workspaces)
yarn example android
yarn example ios

# Library development
yarn prepare              # Builds library with bob
yarn clean               # Cleans all build artifacts

# Platform-specific building
turbo build:android      # Android with newArch detection
turbo build:ios          # iOS build pipeline
```

### Architecture Testing
```bash
# Test New Architecture
ORG_GRADLE_PROJECT_newArchEnabled=true yarn example android

# Test Old Architecture  
ORG_GRADLE_PROJECT_newArchEnabled=false yarn example android
```

## Platform-Specific Considerations

### iOS Specifics
- **FFMpegKit dependency**: Configured in `VideoTrim.podspec` with `ENV['FFMPEGKIT_PACKAGE']`
- **Frameworks**: Requires `AVFoundation`, `AVKit`, `UIKit`, `Photos`
- **File management**: Uses app Documents directory with `FILE_PREFIX = "trimmedVideo"`
- **UI**: Custom `VideoTrimmerViewController` with native trimming controls
- **Zoom feature**: Implements zoom-on-waiting with 0.5s timer, providing granular trimming via `zoomIfNeeded()` and `startZoomWaitTimer()`

### Android Specifics  
- **Gradle configuration**: Multi-module setup with `newarch`/`oldarch` source sets
- **Composition over inheritance**: `BaseVideoTrimModule` used via composition in both architectures
- **File providers**: Uses Android content providers for file sharing
- **FFMpeg**: Depends on `ffmpeg-mobile` via gradle
- **Zoom feature**: Mirrors iOS zoom behavior in `VideoTrimmerView.java` with `zoomIfNeeded()`, `startZoomWaitTimer()`, and zoom-aware position calculations

## Integration Points

### External Dependencies
- **FFMpegKit**: Core video processing (iOS: CocoaPods, Android: Gradle)
- **React Native Image Picker**: Used in example for file selection
- **Platform file systems**: Both platforms handle local/remote file URLs

### Error Handling Pattern
```typescript
// Consistent error codes across platforms
enum ErrorCode { 
  fail_to_load_media,
  export_to_documents_failed,
  // ... etc
}
```

## Testing & Debugging

### Example App Structure
- **`example/src/App.tsx`**: Complete integration example with event listeners
- **Platform testing**: Separate iOS/Android projects in `example/ios` and `example/android`
- **File management demo**: Shows `listFiles()`, `cleanFiles()`, `deleteFile()` usage

### Common Debugging Points
- **Architecture detection**: Check `isFabric` in runtime logs  
- **File paths**: Both platforms log file operations extensively
- **Event flow**: Monitor event subscriptions in example app pattern
- **Native errors**: FFMpeg processing errors bubble up through event system
- **Zoom behavior**: Check `isZoomedIn` state and `zoomWaitTimer` execution in platform logs
- **Thumbnail generation**: Monitor `regenerateThumbnailsForRange()` calls and MediaMetadataRetriever operations

When modifying this library, always test both architectures and verify event consistency between iOS and Android implementations. The zoom feature should provide identical user experience across platforms with 500ms wait timer and smooth thumbnail transitions.