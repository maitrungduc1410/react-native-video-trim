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
  /**
   * Enable haptic feedback
   * @default true
   */
  enableHapticFeedback?: boolean;
  /**
   * Save the output file to Photos Library. Only video is supported. Note that you have to make sure you have permission to save to Photos Library.
   * @default false
   */
  saveToPhoto?: boolean;
  maxDuration?: number;
  minDuration?: number;
  cancelButtonText?: string;
  saveButtonText?: string;
  enableCancelDialog?: boolean;
  cancelDialogTitle?: string;
  cancelDialogMessage?: string;
  cancelDialogCancelText?: string;
  cancelDialogConfirmText?: string;
  enableSaveDialog?: boolean;
  saveDialogTitle?: string;
  saveDialogMessage?: string;
  saveDialogCancelText?: string;
  saveDialogConfirmText?: string;
  trimmingText?: string;
  fullScreenModalIOS?: boolean;
  /**
   * Type of the file to edit. If video file, recommend to use `video`. If audio file, recommend to use `audio`.
   * @default "video"
   */
  type?: 'video' | 'audio';
  /**
   * Output file extension. If video file, recommend to use `mp4` or `mov`. If audio file, recommend to use `wav` or `m4a`.
   * @default "mp4"
   * @example "mp4", "mov", "wav", "m4a", "3gp", "avi", "mkv", "flv", "wmv", "webm"
   */
  outputExt?: string;
  openDocumentsOnFinish?: boolean;
  openShareSheetOnFinish?: boolean;

  removeAfterSavedToPhoto?: boolean;
  removeAfterFailedToSavePhoto?: boolean;
  removeAfterSavedToDocuments?: boolean;
  removeAfterFailedToSaveDocuments?: boolean;
  /**
   * Remove the file after shared to other apps. Currently only support iOS, on Android there's no way to detect if the file is shared or not.
   * @default false
   */
  removeAfterShared?: boolean;
  /**
   * Remove the file after failed to share to other apps. Currently only support iOS, on Android there's no way to detect if the file is shared or not.
   * @default false
   */
  removeAfterFailedToShare?: boolean;
}

/**
 * Delete a file
 *
 * @param {string} videoPath: absolute non-empty file path to edit
 * @param {EditorConfig} config: editor configuration
 * @returns {void} A **Promise** which resolves `void`
 */
export function showEditor(filePath: string, config: EditorConfig = {}): void {
  VideoTrim.showEditor(filePath, config);
}

/**
 * Clean output files generated at all time
 *
 * @returns {Promise<string[]>} A **Promise** which resolves to array of files
 */
export function listFiles(): Promise<string[]> {
  return VideoTrim.listFiles();
}

/**
 * Clean output files generated at all time
 *
 * @returns {Promise} A **Promise** which resolves to number of deleted files
 */
export function cleanFiles(): Promise<number> {
  return VideoTrim.cleanFiles();
}

/**
 * Delete a file
 *
 * @param {string} filePath: absolute non-empty file path to delete
 * @returns {Promise} A **Promise** which resolves `true` if successful
 */
export function deleteFile(filePath: string): Promise<boolean> {
  if (!filePath?.trim().length) {
    throw new Error('File path cannot be empty!');
  }
  return VideoTrim.deleteFile(filePath);
}

/**
 * Close editor
 */
export function closeEditor(): void {
  return VideoTrim.closeEditor();
}

/**
 * Check if a file is valid audio or video file
 *
 * @returns {Promise} A **Promise** which resolves file info if successful
 */
export function isValidFile(url: string): Promise<boolean> {
  return VideoTrim.isValidFile(url);
}
