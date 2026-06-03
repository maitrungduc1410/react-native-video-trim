import VideoTrimNewArch from './NativeVideoTrim';
import VideoTrimOldArch from './OldArch';
import type {
  BaseOptions,
  CompressOptions,
  CompressResult,
  EditorConfig,
  ExtractAudioOptions,
  ExtractAudioResult,
  FileValidationResult,
  FrameExtractionOptions,
  FrameResult,
  GifOptions,
  GifResult,
  MergeOptions,
  MergeResult,
  SaveToDocumentsResult,
  SaveToPhotoResult,
  ShareResult,
  TrimOptions,
  TrimResult,
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
    enablePreciseTrimming: false,
    removeAudio: false,
    speed: 1.0,
    ...overrides,
  };
}

function createCompressOptions(
  overrides: Partial<CompressOptions> = {}
): CompressOptions {
  return {
    quality: 'medium',
    bitrate: -1,
    width: -1,
    height: -1,
    frameRate: -1,
    outputExt: 'mp4',
    removeAudio: false,
    ...overrides,
  };
}

function createFrameExtractionOptions(
  overrides: Partial<FrameExtractionOptions> = {}
): FrameExtractionOptions {
  return {
    time: 0,
    format: 'jpeg',
    quality: 80,
    maxWidth: -1,
    maxHeight: -1,
    ...overrides,
  };
}

function createExtractAudioOptions(
  overrides: Partial<ExtractAudioOptions> = {}
): ExtractAudioOptions {
  return {
    outputExt: 'm4a',
    ...overrides,
  };
}

function createGifOptions(overrides: Partial<GifOptions> = {}): GifOptions {
  return {
    startTime: 0,
    endTime: -1,
    fps: 10,
    width: -1,
    ...overrides,
  };
}

function createMergeOptions(
  overrides: Partial<MergeOptions> = {}
): MergeOptions {
  return {
    outputExt: 'mp4',
    ...overrides,
  };
}

function createEditorConfig(
  overrides: Partial<EditorConfig> = {}
): EditorConfig {
  return {
    enableHapticFeedback: true,
    enableEditTools: true,
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
    zoomOnWaitingDuration: 5000,
    alertOnFailToLoad: true,
    alertOnFailTitle: 'Error',
    alertOnFailMessage:
      'Fail to load media. Possibly invalid file or no network connection',
    alertOnFailCloseText: 'Close',
    waveformColor: processColor('white') as number,
    waveformBackgroundColor: processColor('#3478F6') as number,
    waveformBarWidth: 3,
    waveformBarGap: 2,
    waveformBarCornerRadius: 1.5,
    durationFormat: 'mm:ss.SSS',
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
    Omit<
      EditorConfig,
      | 'headerTextColor'
      | 'trimmerColor'
      | 'handleIconColor'
      | 'waveformColor'
      | 'waveformBackgroundColor'
    >
  > & {
    headerTextColor?: string;
    trimmerColor?: string;
    handleIconColor?: string;
    waveformColor?: string;
    waveformBackgroundColor?: string;
  }
): void {
  const {
    headerTextColor,
    trimmerColor,
    handleIconColor,
    waveformColor,
    waveformBackgroundColor,
  } = config;
  const isLight = config.theme === 'light';
  const _headerTextColor = processColor(
    headerTextColor || (isLight ? 'black' : 'white')
  );
  const _trimmerColor = processColor(trimmerColor || '#f1d247');
  const _handleIconColor = processColor(
    handleIconColor || (isLight ? 'white' : 'black')
  );
  const _waveformColor = processColor(waveformColor || 'white');
  const _waveformBackgroundColor = processColor(
    waveformBackgroundColor || '#3478F6'
  );

  VideoTrim.showEditor(
    filePath,
    createEditorConfig({
      ...config,
      headerTextColor: _headerTextColor as any,
      trimmerColor: _trimmerColor as any,
      handleIconColor: _handleIconColor as any,
      waveformColor: _waveformColor as any,
      waveformBackgroundColor: _waveformBackgroundColor as any,
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
 * @returns {Promise<TrimResult>} A **Promise** which resolves to the TrimResult interface
 */
export function trim(
  url: string,
  options: Partial<TrimOptions>
): Promise<TrimResult> {
  return VideoTrim.trim(url, createTrimOptions(options));
}

/**
 * Extract a single frame from a video at a given timestamp
 *
 * @param {string} url: absolute non-empty file path
 * @param {Partial<FrameExtractionOptions>} options: extraction options
 * @returns {Promise<FrameResult>} A **Promise** which resolves to the FrameResult
 */
export function getFrameAt(
  url: string,
  options: Partial<FrameExtractionOptions> = {}
): Promise<FrameResult> {
  return VideoTrim.getFrameAt(url, createFrameExtractionOptions(options));
}

/**
 * Extract the audio track from a video file
 *
 * @param {string} url: absolute non-empty file path
 * @param {Partial<ExtractAudioOptions>} options: extraction options
 * @returns {Promise<ExtractAudioResult>} A **Promise** which resolves to the result
 */
export function extractAudio(
  url: string,
  options: Partial<ExtractAudioOptions> = {}
): Promise<ExtractAudioResult> {
  return VideoTrim.extractAudio(url, createExtractAudioOptions(options));
}

/**
 * Compress a video file to reduce its size
 *
 * @param {string} url: absolute non-empty file path
 * @param {Partial<CompressOptions>} options: compression options
 * @returns {Promise<CompressResult>} A **Promise** which resolves to the result
 */
export function compress(
  url: string,
  options: Partial<CompressOptions> = {}
): Promise<CompressResult> {
  return VideoTrim.compress(url, createCompressOptions(options));
}

/**
 * Convert a video segment to an animated GIF
 *
 * @param {string} url: absolute non-empty file path
 * @param {Partial<GifOptions>} options: GIF conversion options
 * @returns {Promise<GifResult>} A **Promise** which resolves to the result
 */
export function toGif(
  url: string,
  options: Partial<GifOptions> = {}
): Promise<GifResult> {
  return VideoTrim.toGif(url, createGifOptions(options));
}

/**
 * Merge multiple media files into a single file (headless, no UI)
 *
 * @param {string[]} urls: array of file paths to merge in order
 * @param {Partial<MergeOptions>} options: merge options
 * @returns {Promise<MergeResult>} A **Promise** which resolves to the result
 */
export function merge(
  urls: string[],
  options: Partial<MergeOptions> = {}
): Promise<MergeResult> {
  if (!urls?.length) {
    throw new Error('URLs array cannot be empty!');
  }
  return VideoTrim.merge(urls, createMergeOptions(options));
}

/**
 * Save a file to the device's photo library
 *
 * @param {string} filePath: absolute path to the file
 * @returns {Promise<SaveToPhotoResult>} A **Promise** which resolves to the result
 */
export function saveToPhoto(filePath: string): Promise<SaveToPhotoResult> {
  if (!filePath?.trim().length) {
    throw new Error('File path cannot be empty!');
  }
  return VideoTrim.saveToPhoto(filePath);
}

/**
 * Present the system document picker to save a file
 *
 * @param {string} filePath: absolute path to the file
 * @returns {Promise<SaveToDocumentsResult>} A **Promise** which resolves to the result
 */
export function saveToDocuments(
  filePath: string
): Promise<SaveToDocumentsResult> {
  if (!filePath?.trim().length) {
    throw new Error('File path cannot be empty!');
  }
  return VideoTrim.saveToDocuments(filePath);
}

/**
 * Open the system share sheet for a file
 *
 * @param {string} filePath: absolute path to the file
 * @returns {Promise<ShareResult>} A **Promise** which resolves to the result
 */
export function share(filePath: string): Promise<ShareResult> {
  if (!filePath?.trim().length) {
    throw new Error('File path cannot be empty!');
  }
  return VideoTrim.share(filePath);
}

export * from './NativeVideoTrim';
export default VideoTrim;
