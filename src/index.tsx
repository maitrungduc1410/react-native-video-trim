import VideoTrimNewArch from './NativeVideoTrim';
import VideoTrimOldArch from './OldArch';
import type {
  BaseOptions,
  EditorConfig,
  FileValidationResult,
  TrimOptions,
} from './NativeVideoTrim';
import { processColor } from 'react-native';

// React Native runtime flags like nativeFabricUIManager are not in TypeScript types. Using `any` here is intentional and safe.
const isFabric = !!(global as any).nativeFabricUIManager;
const VideoTrim = isFabric ? VideoTrimNewArch : VideoTrimOldArch;

function createBaseOptions(overrides: Partial<BaseOptions> = {}): BaseOptions {
  return {
    saveToPhoto: false,
    type: 'video',
    outputExt: 'mp4',
    removeAfterSavedToPhoto: false,
    removeAfterFailedToSavePhoto: false,
    enableRotation: false,
    rotationAngle: 0,
    ...overrides,
  };
}

function createEditorConfig(
  overrides: Partial<EditorConfig> = {}
): EditorConfig {
  return {
    enableHapticFeedback: true,
    maxDuration: -1,
    minDuration: -1,
    openDocumentsOnFinish: false,
    openShareSheetOnFinish: false,
    removeAfterSavedToDocuments: false,
    removeAfterFailedToSaveDocuments: false,
    removeAfterShared: false,
    removeAfterFailedToShare: false,
    cancelButtonText: 'Cancel',
    saveButtonText: 'Save',
    enableCancelDialog: true,
    cancelDialogTitle: 'Warning!',
    cancelDialogMessage: 'Are you sure want to cancel?',
    cancelDialogCancelText: 'Close',
    cancelDialogConfirmText: 'Proceed',
    enableSaveDialog: true,
    saveDialogTitle: 'Confirmation!',
    saveDialogMessage: 'Are you sure want to save?',
    saveDialogCancelText: 'Close',
    saveDialogConfirmText: 'Proceed',
    trimmingText: 'Trimming video...',
    fullScreenModalIOS: false,
    autoplay: false,
    jumpToPositionOnLoad: -1,
    closeWhenFinish: true,
    enableCancelTrimming: true,
    cancelTrimmingButtonText: 'Cancel',
    enableCancelTrimmingDialog: true,
    cancelTrimmingDialogTitle: 'Warning!',
    cancelTrimmingDialogMessage: 'Are you sure want to cancel trimming?',
    cancelTrimmingDialogCancelText: 'Close',
    cancelTrimmingDialogConfirmText: 'Proceed',
    headerText: '',
    headerTextSize: 16,
    headerTextColor: processColor('white') as number,
    trimmerColor: processColor('#f1d247') as number,
    handleIconColor: processColor('black') as number,
    alertOnFailToLoad: true,
    alertOnFailTitle: 'Error',
    alertOnFailMessage:
      'Fail to load media. Possibly invalid file or no network connection',
    alertOnFailCloseText: 'Close',
    ...createBaseOptions(overrides),
    ...overrides,
  };
}

function createTrimOptions(overrides: Partial<TrimOptions> = {}): TrimOptions {
  return {
    startTime: 0,
    endTime: 1000,
    ...createBaseOptions(overrides),
    ...overrides,
  };
}

/**
 * Show video editor
 *
 * @param {string} filePath: absolute non-empty file path to edit
 * @param {EditorConfig} config: editor configuration
 * @param {Function} onEvent: event callback
 * @returns {void}
 */
export function showEditor(
  filePath: string,
  config: Partial<
    Omit<EditorConfig, 'headerTextColor' | 'trimmerColor' | 'handleIconColor'>
  > & {
    headerTextColor?: string;
    trimmerColor?: string;
    handleIconColor?: string;
  }
): void {
  const { headerTextColor, trimmerColor, handleIconColor } = config;
  const _headerTextColor = processColor(headerTextColor || 'white');
  const _trimmerColor = processColor(trimmerColor || '#f1d247');
  const _handleIconColor = processColor(handleIconColor || 'black');

  VideoTrim.showEditor(
    filePath,
    createEditorConfig({
      ...config,
      headerTextColor: _headerTextColor as any,
      trimmerColor: _trimmerColor as any,
      handleIconColor: _handleIconColor as any,
    })
  );
}

/**
 * List output files generated at all time
 *
 * @returns {Promise<string[]>} A **Promise** which resolves to array of files
 */
export function listFiles(): Promise<string[]> {
  return VideoTrim.listFiles();
}

/**
 * Clean output files generated at all time
 *
 * @returns {Promise<number>} A **Promise** which resolves to number of deleted files
 */
export function cleanFiles(): Promise<number> {
  return VideoTrim.cleanFiles();
}

/**
 * Delete a file
 *
 * @param {string} filePath: absolute non-empty file path to delete
 * @returns {Promise<boolean>} A **Promise** which resolves `true` if successful
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
 * @param {string} url: file path to validate
 * @returns {Promise<FileValidationResult>} A **Promise** which resolves file info if successful
 */
export function isValidFile(url: string): Promise<FileValidationResult> {
  return VideoTrim.isValidFile(url);
}

/**
 * Trim a video file
 *
 * @param {string} url: absolute non-empty file path to edit
 * @param {TrimOptions} options: trim options
 * @returns {Promise<string>} A **Promise** which resolves to the trimmed file path
 */
export function trim(
  url: string,
  options: Partial<TrimOptions>
): Promise<string> {
  return VideoTrim.trim(url, createTrimOptions(options));
}

export * from './NativeVideoTrim';
export default VideoTrim;
