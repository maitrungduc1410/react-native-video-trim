import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-video-trim' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const VideoTrim = NativeModules.VideoTrim
  ? NativeModules.VideoTrim
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export interface EditorConfig {
  saveToPhoto?: boolean;
  maxDuration?: number;
}

export function showEditor(videoPath: string, config: EditorConfig = {}): void {
  const { maxDuration, saveToPhoto = true } = config;
  VideoTrim.showEditor(videoPath, {
    saveToPhoto,
    maxDuration,
  });
}

export function isValidVideo(videoPath: string): Promise<boolean> {
  return VideoTrim.isValidVideo(videoPath);
}
