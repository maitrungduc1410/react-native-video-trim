import type { HybridObject } from 'react-native-nitro-modules';

export interface BaseOptions {
  /**
   * Save the output file to Photos Library. Only video is supported. Note that you have to make sure you have permission to save to Photos Library.
   * @default false
   */
  saveToPhoto: boolean;
  /**
   * Type of the file to edit. If video file, recommend to use `video`. If audio file, recommend to use `audio`.
   * @default "video"
   */
  type: string;
  /**
   * Output file extension. If video file, recommend to use `mp4` or `mov`. If audio file, recommend to use `wav` or `m4a`.
   * @default "mp4"
   * @example "mp4", "mov", "wav", "m4a", "3gp", "avi", "mkv", "flv", "wmv", "webm"
   */
  outputExt: string;
  /**
   * Whether to open Documents app after finish editing
   * @default false
   */
  openDocumentsOnFinish: boolean;
  /**
   * Whether to open Share Sheet after finish editing
   * @default false
   */
  openShareSheetOnFinish: boolean;
  /**
   * Remove the file after saved to Photos Library
   * @default false
   */
  removeAfterSavedToPhoto: boolean;
  /**
   * Remove the file after failed to save to Photos Library
   * @default false
   */
  removeAfterFailedToSavePhoto: boolean;
  /**
   * Remove the file after saved to Documents app
   * @default false
   */
  removeAfterSavedToDocuments: boolean;
  /**
   * Remove the file after failed to save to Documents app
   * @default false
   */
  removeAfterFailedToSaveDocuments: boolean;
  /**
   * Remove the file after shared to other apps. Currently only support iOS, on Android there's no way to detect if the file is shared or not.
   * @default false
   */
  removeAfterShared: boolean;
  /**
   * Remove the file after failed to share to other apps. Currently only support iOS, on Android there's no way to detect if the file is shared or not.
   * @default false
   */
  removeAfterFailedToShare: boolean;
  /**
   * Enable rotation
   * @default false
   */
  enableRotation: boolean;
  /**
   * Rotation angle in degrees
   * @default 0
   */
  rotationAngle: number;
}

export interface EditorConfig extends BaseOptions {
  /**
   * Enable haptic feedback
   * @default true
   */
  enableHapticFeedback: boolean;
  maxDuration: number;
  /**
   * Minimum duration for trimmer
   * @default 1000
   */
  minDuration: number;
  /**
   * Cancel button text
   * @default "Cancel"
   */
  cancelButtonText: string;
  /**
   * Save button text
   * @default "Save"
   */
  saveButtonText: string;
  /**
   * Enable cancel dialog
   * @default true
   */
  enableCancelDialog: boolean;
  /**
   * Cancel dialog title
   * @default "Warning!"
   */
  cancelDialogTitle: string;
  /**
   * Cancel dialog message
   * @default "Are you sure want to cancel?"
   */
  cancelDialogMessage: string;
  /**
   * Cancel dialog cancel text
   * @default "Close"
   */
  cancelDialogCancelText: string;
  /**
   * Cancel dialog confirm text
   * @default "Proceed"
   */
  cancelDialogConfirmText: string;
  /**
   * Enable save dialog
   * @default true
   */
  enableSaveDialog: boolean;
  /**
   * Save dialog title
   * @default "Confirmation!"
   */
  saveDialogTitle: string;
  /**
   * Save dialog message
   * @default "Are you sure want to save?"
   */
  saveDialogMessage: string;
  /**
   * Save dialog cancel text
   * @default "Close"
   */
  saveDialogCancelText: string;
  /**
   * Save dialog confirm text
   * @default "Proceed"
   */
  saveDialogConfirmText: string;
  /**
   * Trimming text
   * @default "Trimming video..."
   */
  trimmingText: string;
  /**
   * By default, on iOS the editor will be presented as a modal. If you want to present it as a full screen modal, set this to `true`.
   * @default false
   */
  fullScreenModalIOS: boolean;
  /**
   * Whether to enable autoplay on load
   */
  autoplay: boolean;
  /**
   * Jump to position on load in milliseconds
   * @default `undefined` (beginning of the video)
   */
  jumpToPositionOnLoad: number;
  /**
   * Whether to close the editor when finish editing
   * @default true
   */
  closeWhenFinish: boolean;
  /**
   * Enable cancel trimming
   * @default true
   */
  enableCancelTrimming: boolean;
  /**
   * Cancel trimming button text
   * @default "Cancel"
   */
  cancelTrimmingButtonText: string;
  /**
   * Enable cancel trimming dialog
   * @default true
   */
  enableCancelTrimmingDialog: boolean;
  /**
   * Cancel trimming dialog title
   * @default "Warning!"
   */
  cancelTrimmingDialogTitle: string;
  /**
   * Cancel trimming dialog message
   * @default "Are you sure want to cancel trimming?"
   */
  cancelTrimmingDialogMessage: string;
  /**
   * Cancel trimming dialog cancel text
   * @default "Close"
   */
  cancelTrimmingDialogCancelText: string;
  /**
   * Cancel trimming dialog confirm text
   * @default "Proceed"
   */
  cancelTrimmingDialogConfirmText: string;
  /**
   * Header text
   */
  headerText: string;
  /**
   * Header text size
   * @default 16
   */
  headerTextSize: number;
  /**
   * Header text color
   * @default white
   */
  headerTextColor: number;
  /**
   * Alert on fail to load media
   * @default true
   */
  alertOnFailToLoad: boolean;
  /**
   * Alert on fail to load media title
   * @default "Error"
   */
  alertOnFailTitle: string;
  /**
   * Alert on fail to load media message
   * @default "Fail to load media. Possibly invalid file or no network connection"
   */
  alertOnFailMessage: string;
  /**
   * Alert on fail to load media close text
   * @default "Close"
   */
  alertOnFailCloseText: string;
}

export interface TrimOptions extends BaseOptions {
  startTime: number; // in milliseconds
  endTime: number; // in milliseconds
}

export interface FileValidationResult {
  isValid: boolean;
  fileType: string;
  duration: number;
}

export interface VideoTrim
  extends HybridObject<{ ios: 'swift'; android: 'kotlin' }> {
  showEditor(
    filePath: string,
    config: EditorConfig,
    onEvent: (eventName: string, payload: Record<string, string>) => void // currently nitro modules will fail if there are 2 optional callbacks, to make if work, we need to pass the onEvent as the last parameter
  ): void;
  listFiles(): Promise<string[]>;
  cleanFiles(): Promise<number>;
  deleteFile(filePath: string): Promise<boolean>;
  closeEditor(onComplete: () => void): void;
  isValidFile(url: string): Promise<FileValidationResult>;
  trim(url: string, options: TrimOptions): Promise<string>;
}
