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
  MixAudioOptions,
  MixAudioResult,
  SaveToDocumentsResult,
  SaveToPhotoResult,
  ShareResult,
  TrimOptions,
  TrimResult,
  Spec,
} from './NativeVideoTrim';
import type { EditorOptions } from './types';
import { processColor } from 'react-native';

// React Native runtime flags like nativeFabricUIManager are not in TypeScript types. Using `any` here is intentional and safe.
const isFabric = !!(global as any).nativeFabricUIManager;
/**
 * The native module. Call the named functions ({@link showEditor},
 * {@link trim}, ...) for everything else; use the default export to subscribe
 * to editor events on the New Architecture. Each `on*` emitter takes a listener
 * and returns a subscription with `remove()`. Payloads are described in
 * {@link VideoTrimEventMap}.
 *
 * @example
 * ```ts
 * import VideoTrim from 'react-native-video-trim';
 *
 * const sub = VideoTrim.onFinishTrimming(({ outputPath, duration }) => {
 *   console.log(outputPath, duration);
 * });
 * // later
 * sub.remove();
 * ```
 */
const VideoTrim: Spec = isFabric ? VideoTrimNewArch : VideoTrimOldArch;

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
    removeAudio: false,
    ...overrides,
  };
}

function createMixAudioOptions(
  overrides: Partial<MixAudioOptions> = {}
): MixAudioOptions {
  return {
    originalAudioVolume: 1.0,
    backgroundAudioVolume: 1.0,
    audioStartTime: 0,
    loopAudio: false,
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
 * Open the full-screen trimmer editor for a video or audio file.
 *
 * The call returns immediately. Follow what happens in the editor through the
 * events on the default export (New Architecture) or the `"VideoTrim"` native
 * event (Old Architecture); see {@link VideoTrimEventMap}.
 *
 * @param filePath - Local path, `file://` URI or (with the `https` FFmpegKit
 *   package) an HTTPS URL of the media to edit.
 * @param config - Editor options. Every field is optional.
 *
 * @example
 * ```ts
 * import { showEditor } from 'react-native-video-trim';
 *
 * showEditor(videoUri, {
 *   maxDuration: 30_000, // milliseconds
 *   saveToPhoto: true,
 * });
 * ```
 */
export function showEditor(filePath: string, config: EditorOptions): void {
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
 * List every output file the library has produced and not yet deleted, in both
 * the persistent and the cache output directories.
 *
 * @returns Absolute paths of the files.
 */
export function listFiles(): Promise<string[]> {
  return VideoTrim.listFiles();
}

/**
 * Delete every output file the library has produced, in both the persistent
 * and the cache output directories.
 *
 * @returns The number of files deleted.
 */
export function cleanFiles(): Promise<number> {
  return VideoTrim.cleanFiles();
}

/**
 * Delete one output file. On Android, only files inside the library's own
 * output directories can be deleted; other paths resolve `false`.
 *
 * @param filePath - Absolute path of the file, as returned by another API.
 * @returns `true` when the file was deleted (or, on Android, did not exist).
 * @throws Error synchronously when `filePath` is empty.
 */
export function deleteFile(filePath: string): Promise<boolean> {
  if (!filePath?.trim().length) {
    throw new Error('File path cannot be empty!');
  }
  return VideoTrim.deleteFile(filePath);
}

/**
 * Close the editor if it is open.
 */
export function closeEditor(): void {
  return VideoTrim.closeEditor();
}

/**
 * Check whether a file is a playable audio or video file.
 *
 * @param url - Local path or URL of the file.
 * @returns Whether the file is valid, its type and its duration.
 *
 * @example
 * ```ts
 * const { isValid, fileType, duration } = await isValidFile(uri);
 * ```
 */
export function isValidFile(url: string): Promise<FileValidationResult> {
  return VideoTrim.isValidFile(url);
}

/**
 * Trim a video or audio file without showing any UI.
 *
 * @param url - Local path or URL of the media.
 * @param options - Trim range and output options. Times are in milliseconds.
 * @returns The trimmed range and the output path.
 *
 * @example
 * ```ts
 * const { outputPath } = await trim(videoUri, {
 *   startTime: 5_000,
 *   endTime: 25_000,
 * });
 * ```
 */
export function trim(
  url: string,
  options: Partial<TrimOptions>
): Promise<TrimResult> {
  return VideoTrim.trim(url, createTrimOptions(options));
}

/**
 * Extract a single frame from a video as a JPEG or PNG image.
 *
 * @param url - Local path of the video.
 * @param options - Timestamp, format and size of the frame.
 * @returns The path of the image, written to the cache directory.
 *
 * @example
 * ```ts
 * const { outputPath } = await getFrameAt(videoUri, { time: 5_000, maxWidth: 640 });
 * ```
 */
export function getFrameAt(
  url: string,
  options: Partial<FrameExtractionOptions> = {}
): Promise<FrameResult> {
  return VideoTrim.getFrameAt(url, createFrameExtractionOptions(options));
}

/**
 * Extract the audio track of a video into a separate audio file.
 *
 * @param url - Local path of the video.
 * @param options - Output format. Defaults to `m4a` (AAC).
 * @returns The path and duration of the audio file, written to the cache directory.
 *
 * @example
 * ```ts
 * const { outputPath, duration } = await extractAudio(videoUri);
 * ```
 */
export function extractAudio(
  url: string,
  options: Partial<ExtractAudioOptions> = {}
): Promise<ExtractAudioResult> {
  return VideoTrim.extractAudio(url, createExtractAudioOptions(options));
}

/**
 * Re-encode a video to make it smaller.
 *
 * @param url - Local path of the video.
 * @param options - Quality preset, or explicit bitrate, size and frame rate.
 * @returns The path of the compressed video, written to the cache directory.
 *
 * @example
 * ```ts
 * const { outputPath } = await compress(videoUri, { quality: 'medium' });
 * ```
 */
export function compress(
  url: string,
  options: Partial<CompressOptions> = {}
): Promise<CompressResult> {
  return VideoTrim.compress(url, createCompressOptions(options));
}

/**
 * Convert a segment of a video to an animated GIF.
 *
 * @param url - Local path of the video.
 * @param options - Segment, frame rate and width of the GIF.
 * @returns The path of the GIF, written to the cache directory.
 *
 * @example
 * ```ts
 * const { outputPath } = await toGif(videoUri, { startTime: 2_000, endTime: 7_000, fps: 15, width: 320 });
 * ```
 */
export function toGif(
  url: string,
  options: Partial<GifOptions> = {}
): Promise<GifResult> {
  return VideoTrim.toGif(url, createGifOptions(options));
}

/**
 * Concatenate several clips into one file, in order. Clips may differ in
 * resolution, frame rate and codec; they are converted to match the first
 * clip. Only local files are supported.
 *
 * @param urls - Local paths of the clips, in playback order.
 * @param options - Output options.
 * @returns The path and duration of the merged file, written to the cache directory.
 * @throws Error synchronously when `urls` is empty.
 *
 * @example
 * ```ts
 * const { outputPath } = await merge([clip1, clip2, clip3]);
 * ```
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
 * Mix (or replace) an external audio track, such as background music or a
 * voice-over, into a video. The video stream is copied unchanged, so only the
 * audio is re-encoded. Only local files are supported.
 *
 * @param videoPath - Local path of the source video.
 * @param audioPath - Local path of the audio to mix in.
 * @param options - Volumes, start offset and looping.
 * @returns The path and duration of the output video, written to the cache directory.
 * @throws Error synchronously when either path is empty.
 *
 * @example
 * ```ts
 * // Replace the original audio with a voice-over
 * const { outputPath } = await mixAudio(videoPath, voiceOverPath, {
 *   originalAudioVolume: 0,
 * });
 * ```
 */
export function mixAudio(
  videoPath: string,
  audioPath: string,
  options: Partial<MixAudioOptions> = {}
): Promise<MixAudioResult> {
  if (!videoPath?.trim().length) {
    throw new Error('Video path cannot be empty!');
  }
  if (!audioPath?.trim().length) {
    throw new Error('Audio path cannot be empty!');
  }
  return VideoTrim.mixAudio(
    videoPath,
    audioPath,
    createMixAudioOptions(options)
  );
}

/**
 * Save an image or video to the device's photo library. Requires photo
 * library permission.
 *
 * @param filePath - Absolute path of the file.
 * @returns Whether the file was saved.
 * @throws Error synchronously when `filePath` is empty.
 */
export function saveToPhoto(filePath: string): Promise<SaveToPhotoResult> {
  if (!filePath?.trim().length) {
    throw new Error('File path cannot be empty!');
  }
  return VideoTrim.saveToPhoto(filePath);
}

/**
 * Let the user save a file to a location of their choice with the system
 * document picker.
 *
 * @param filePath - Absolute path of the file.
 * @returns Whether the file was saved.
 * @throws Error synchronously when `filePath` is empty.
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
 * Open the system share sheet for a file.
 *
 * @param filePath - Absolute path of the file. On Android it must be inside
 *   the library's output directories.
 * @returns Whether the user completed the share.
 * @throws Error synchronously when `filePath` is empty.
 */
export function share(filePath: string): Promise<ShareResult> {
  if (!filePath?.trim().length) {
    throw new Error('File path cannot be empty!');
  }
  return VideoTrim.share(filePath);
}

export type {
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
  MixAudioOptions,
  MixAudioResult,
  SaveToDocumentsResult,
  SaveToPhotoResult,
  ShareResult,
  Spec,
  TrimOptions,
  TrimResult,
} from './NativeVideoTrim';
export type {
  EditorOptions,
  ErrorCode,
  FinishTrimmingEvent,
  LoadEvent,
  LogEvent,
  StatisticsEvent,
  VideoTrimErrorEvent,
  VideoTrimEvent,
  VideoTrimEventMap,
  VideoTrimEventName,
} from './types';
export default VideoTrim;