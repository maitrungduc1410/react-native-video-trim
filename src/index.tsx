import { NativeModules, PermissionsAndroid, Platform } from 'react-native';

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

export async function showEditor(
  videoPath: string,
  config: EditorConfig = {}
): Promise<void> {
  const { maxDuration, saveToPhoto = true } = config;
  const outputPath = await VideoTrim.showEditor(videoPath, {
    saveToPhoto,
    maxDuration,
  });

  if (Platform.OS === 'android' && saveToPhoto) {
    try {
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE!,
        {
          title: 'Video Trimmer Camera Access Required',
          message: 'Grant access to your Camera to write output Video',
          buttonNeutral: 'Ask Me Later',
          buttonNegative: 'Cancel',
          buttonPositive: 'OK',
        }
      );
      if (granted === PermissionsAndroid.RESULTS.GRANTED) {
        await VideoTrim.saveVideo(outputPath);
      } else {
        VideoTrim.hideDialog();
        throw new Error('Camera permission denied');
      }
    } catch (err) {
      throw err;
    }
  }
}

export function isValidVideo(videoPath: string): Promise<boolean> {
  return VideoTrim.isValidVideo(videoPath);
}
