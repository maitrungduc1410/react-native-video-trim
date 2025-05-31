import { NitroModules } from 'react-native-nitro-modules';
import type {
  BaseOptions,
  EditorConfig,
  FileValidationResult,
  TrimOptions,
  VideoTrim,
} from './VideoTrim.nitro';
import { processColor } from 'react-native';

const VideoTrimHybridObject =
  NitroModules.createHybridObject<VideoTrim>('VideoTrim');

function createBaseOptions(overrides: Partial<BaseOptions> = {}): BaseOptions {
  return {
    saveToPhoto: false,
    type: 'video',
    outputExt: 'mp4',
    openDocumentsOnFinish: false,
    openShareSheetOnFinish: false,
    removeAfterSavedToPhoto: false,
    removeAfterFailedToSavePhoto: false,
    removeAfterSavedToDocuments: false,
    removeAfterFailedToSaveDocuments: false,
    removeAfterShared: false,
    removeAfterFailedToShare: false,
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
    maxDuration: -1, // Adjust default as needed
    minDuration: 1000,
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
    autoplay: false, // Adjust default as needed
    jumpToPositionOnLoad: -1,
    closeWhenFinish: true,
    enableCancelTrimming: true,
    cancelTrimmingButtonText: 'Cancel',
    enableCancelTrimmingDialog: true,
    cancelTrimmingDialogTitle: 'Warning!',
    cancelTrimmingDialogMessage: 'Are you sure want to cancel trimming?',
    cancelTrimmingDialogCancelText: 'Close',
    cancelTrimmingDialogConfirmText: 'Proceed',
    headerText: '', // Adjust default as needed
    headerTextSize: 16,
    headerTextColor: processColor('white') as number,
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

function noop() {}

/**
 * Delete a file
 *
 * @param {string} videoPath: absolute non-empty file path to edit
 * @param {EditorConfig} config: editor configuration
 * @returns {void} A **Promise** which resolves `void`
 */
export function showEditor(
  filePath: string,
  config: Partial<Omit<EditorConfig, 'headerTextColor'>> & {
    headerTextColor?: string;
  },
  onEvent?: (eventName: string, payload: Record<string, string>) => void
): void {
  const { headerTextColor } = config;
  const color = processColor(headerTextColor || 'white');

  VideoTrimHybridObject.showEditor(
    filePath,
    createEditorConfig({
      ...config,
      headerTextColor: color as any,
    }),
    onEvent || noop
  );
}

/**
 * Clean output files generated at all time
 *
 * @returns {Promise<string[]>} A **Promise** which resolves to array of files
 */
export function listFiles(): Promise<string[]> {
  return VideoTrimHybridObject.listFiles();
}

/**
 * Clean output files generated at all time
 *
 * @returns {Promise} A **Promise** which resolves to number of deleted files
 */
export function cleanFiles(): Promise<number> {
  return VideoTrimHybridObject.cleanFiles();
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
  return VideoTrimHybridObject.deleteFile(filePath);
}

/**
 * Close editor
 */
export function closeEditor(onComplete?: () => void): void {
  return VideoTrimHybridObject.closeEditor(onComplete || noop);
}

/**
 * Check if a file is valid audio or video file
 *
 * @returns {Promise} A **Promise** which resolves file info if successful
 */
export function isValidFile(url: string): Promise<FileValidationResult> {
  return VideoTrimHybridObject.isValidFile(url);
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
  return VideoTrimHybridObject.trim(url, createTrimOptions(options));
}
