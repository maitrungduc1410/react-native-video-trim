import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';
import type { EventEmitter } from 'react-native/Libraries/Types/CodegenTypes';

/**
 * Base options shared by both the editor and headless trim operations.
 */
export interface BaseOptions {
  /** Whether to save the output file to the device's photo library. */
  saveToPhoto: boolean;
  /** Media type: `"video"` or `"audio"`. */
  type: string;
  /** Output file extension (e.g. `"mp4"`, `"wav"`). */
  outputExt: string;
  /** Whether to remove the output file after it has been saved to the photo library. */
  removeAfterSavedToPhoto: boolean;
  /** Whether to remove the output file if saving to the photo library fails. */
  removeAfterFailedToSavePhoto: boolean;
  /**
   * When `true`, FFmpeg re-encodes the video using the platform's hardware encoder
   * (h264_videotoolbox on iOS, h264_mediacodec on Android) for frame-accurate trimming.
   * When `false` (default), uses stream copy (`-c copy`) which is much faster but can
   * only cut at keyframes, so the actual start/end may drift by several seconds.
   *
   * Note: if the user applies any transform (flip/rotate/crop), re-encoding already
   * happens regardless of this flag, so precise trimming comes for free in that case.
   */
  enablePreciseTrimming: boolean;
  /**
   * When `true`, strips the audio track from the output. Default `false`.
   * In the editor, playback also starts muted, and the output has no audio
   * even if the user unmutes.
   */
  removeAudio: boolean;
  /**
   * Playback speed multiplier applied during export. `1.0` is normal speed,
   * `2.0` is double speed, `0.5` is half speed. Valid range: 0.25–4.0.
   * When not `1.0`, re-encoding is forced regardless of `enablePreciseTrimming`.
   */
  speed: number;
}

/**
 * Configuration for the video trimmer editor UI.
 */
export interface EditorConfig extends BaseOptions {
  /** Whether to enable haptic feedback when interacting with the trimmer. */
  enableHapticFeedback: boolean;
  /**
   * Whether to show the top toolbar of edit tools (flip, rotate, crop, mute,
   * speed, undo, redo). Set to `false` to hide the entire toolbar. Default `true`.
   * Video only: the toolbar never appears for audio files.
   */
  enableEditTools: boolean;
  /** Maximum allowed duration for the trimmed clip in milliseconds. Set to `-1` for no limit. */
  maxDuration: number;
  /**
   * Minimum allowed duration for the trimmed clip in milliseconds. Set to `-1`
   * for no limit. The editor never allows a selection shorter than 1 second.
   */
  minDuration: number;
  /** Whether to open the system document picker to save the output after trimming finishes. */
  openDocumentsOnFinish: boolean;
  /** Whether to open the share sheet after trimming finishes. */
  openShareSheetOnFinish: boolean;
  /** Whether to remove the output file after it has been saved through the document picker. */
  removeAfterSavedToDocuments: boolean;
  /** Whether to remove the output file if saving through the document picker fails. */
  removeAfterFailedToSaveDocuments: boolean;
  /** iOS only. Whether to remove the output file after it has been shared. */
  removeAfterShared: boolean;
  /** iOS only. Whether to remove the output file if sharing fails. */
  removeAfterFailedToShare: boolean;
  /** Text for the cancel button. */
  cancelButtonText: string;
  /** Text for the save button. */
  saveButtonText: string;
  /** Whether to show a confirmation dialog when the cancel button is pressed. */
  enableCancelDialog: boolean;
  /** Title of the cancel confirmation dialog. */
  cancelDialogTitle: string;
  /** Message of the cancel confirmation dialog. */
  cancelDialogMessage: string;
  /** Text for the dismiss button in the cancel confirmation dialog. */
  cancelDialogCancelText: string;
  /** Text for the confirm button in the cancel confirmation dialog. */
  cancelDialogConfirmText: string;
  /** Whether to show a confirmation dialog when the save button is pressed. */
  enableSaveDialog: boolean;
  /** Title of the save confirmation dialog. */
  saveDialogTitle: string;
  /** Message of the save confirmation dialog. */
  saveDialogMessage: string;
  /** Text for the dismiss button in the save confirmation dialog. */
  saveDialogCancelText: string;
  /** Text for the confirm button in the save confirmation dialog. */
  saveDialogConfirmText: string;
  /** Text displayed while the video is being trimmed (e.g. `"Trimming video..."`). */
  trimmingText: string;
  /** iOS only. Whether to present the editor as a full-screen modal. */
  fullScreenModalIOS: boolean;
  /** Whether to auto-play the video when the editor opens. */
  autoplay: boolean;
  /** Position in milliseconds to seek to when the editor loads. Set to `-1` to disable. */
  jumpToPositionOnLoad: number;
  /** Whether to automatically close the editor when trimming finishes. */
  closeWhenFinish: boolean;
  /** Whether the user can cancel a trim that is in progress. */
  enableCancelTrimming: boolean;
  /** Text for the cancel-trimming button. */
  cancelTrimmingButtonText: string;
  /** Whether to show a confirmation dialog when cancelling an in-progress trim. */
  enableCancelTrimmingDialog: boolean;
  /** Title of the cancel-trimming confirmation dialog. */
  cancelTrimmingDialogTitle: string;
  /** Message of the cancel-trimming confirmation dialog. */
  cancelTrimmingDialogMessage: string;
  /** Text for the dismiss button in the cancel-trimming dialog. */
  cancelTrimmingDialogCancelText: string;
  /** Text for the confirm button in the cancel-trimming dialog. */
  cancelTrimmingDialogConfirmText: string;
  /** Custom header text displayed at the top of the editor. */
  headerText: string;
  /** Font size of the header text in sp/pt. */
  headerTextSize: number;
  /** Color of the header text as a `processColor` value. */
  headerTextColor: number;
  /** Whether to show an alert dialog when the media file fails to load. */
  alertOnFailToLoad: boolean;
  /** Title of the fail-to-load alert. */
  alertOnFailTitle: string;
  /** Message of the fail-to-load alert. */
  alertOnFailMessage: string;
  /** Text for the close button of the fail-to-load alert. */
  alertOnFailCloseText: string;
  /** Android only. Whether to update the status bar to a black background when the editor opens. */
  changeStatusBarColorOnOpen?: boolean;
  /** Color of the trimmer bar as a `processColor` value. */
  trimmerColor?: number;
  /** Color of the trimmer left/right handle icons as a `processColor` value. */
  handleIconColor?: number;
  /**
   * How much time, in milliseconds, the timeline shows when it zooms in
   * (default: `5000`). When the user holds a trim handle still while dragging,
   * the timeline zooms in to this span around the handle for finer adjustment.
   */
  zoomOnWaitingDuration?: number;
  /**
   * Editor theme. `"dark"` (default) uses a black background with white UI elements.
   * `"light"` uses a white background with black icons/text and white trimmer-handle chevrons.
   */
  theme?: string;
  /**
   * Format token for the editor's start / current / end time labels.
   * Allowed values:
   * - `"mm:ss"`: minutes:seconds (e.g. `01:23`)
   * - `"mm:ss.SS"`: centiseconds (e.g. `01:23.45`)
   * - `"mm:ss.SSS"`: milliseconds (e.g. `01:23.456`), **default**
   * - `"hh:mm:ss"`: hours:minutes:seconds (e.g. `00:01:23`)
   * - `"hh:mm:ss.SSS"`: hours:minutes:seconds.milliseconds (e.g. `00:01:23.456`)
   *
   * Unknown values fall back to the default. Only affects on-screen labels;
   * `onLoad` / `onFinishTrimming` payloads continue to report raw milliseconds.
   */
  durationFormat?: string;
  /** Color of the audio waveform bars as a `processColor` value. */
  waveformColor?: number;
  /** Background color behind the audio waveform bars as a `processColor` value. */
  waveformBackgroundColor?: number;
  /** Width of each waveform bar in dp/pt (default: `3`). */
  waveformBarWidth?: number;
  /** Gap between waveform bars in dp/pt (default: `2`). */
  waveformBarGap?: number;
  /** Corner radius of waveform bars in dp/pt (default: `1.5`). */
  waveformBarCornerRadius?: number;
}

/**
 * Options for headless (non-UI) trim operations.
 */
export interface TrimOptions extends BaseOptions {
  /** Start time of the trim range in milliseconds. */
  startTime: number;
  /** End time of the trim range in milliseconds. */
  endTime: number;
}

/**
 * Result returned by {@link isValidFile}.
 */
export interface FileValidationResult {
  /** Whether the file is a valid audio or video file. */
  isValid: boolean;
  /** Detected file type (e.g. `"video"`, `"audio"`, `"unknown"`). */
  fileType: string;
  /** Duration of the media file in milliseconds, or `-1` if invalid. */
  duration: number;
}

/**
 * Result returned by a trim operation (both editor and headless).
 */
export interface TrimResult {
  /** Start time of the trimmed range in milliseconds. */
  startTime: number;
  /** End time of the trimmed range in milliseconds. */
  endTime: number;
  /** Duration of the trimmed clip in milliseconds. */
  duration: number;
  /** Absolute path to the trimmed output file. */
  outputPath: string;
  /** Whether the trim operation completed successfully. */
  success: boolean;
}

/**
 * Options for extracting a single frame from a video.
 */
export interface FrameExtractionOptions {
  /** Timestamp in milliseconds at which to extract the frame. */
  time: number;
  /** Output image format: `"jpeg"` (default) or `"png"`. */
  format: string;
  /** JPEG compression quality from 0–100. Default `80`. Ignored for PNG. */
  quality: number;
  /** Maximum width in pixels. Height is auto-calculated to preserve aspect ratio. `-1` for original. */
  maxWidth: number;
  /** Maximum height in pixels. Width is auto-calculated to preserve aspect ratio. `-1` for original. */
  maxHeight: number;
}

/**
 * Result returned by {@link getFrameAt}.
 */
export interface FrameResult {
  /** Absolute path to the extracted image file. */
  outputPath: string;
}

/**
 * Options for extracting the audio track from a video file.
 */
export interface ExtractAudioOptions {
  /**
   * Output audio file extension (e.g. `"m4a"`, `"wav"`). Default `"m4a"` (AAC).
   * `"mp3"` needs an FFmpegKit build with `libmp3lame`, which the default builds lack.
   */
  outputExt: string;
}

/**
 * Result returned by {@link extractAudio}.
 */
export interface ExtractAudioResult {
  /** Absolute path to the extracted audio file. */
  outputPath: string;
  /** Duration of the audio in milliseconds. */
  duration: number;
}

/**
 * Options for compressing a video file.
 */
export interface CompressOptions {
  /**
   * Quality preset: `"low"` (smallest file), `"medium"` (balanced), `"high"` (best quality).
   * On Android the presets target 500 kbps, 2 Mbps and 5 Mbps; on iOS they set
   * FFmpeg `-global_quality` to 28, 23 and 18. Ignored when `bitrate` is set.
   */
  quality: string;
  /** Explicit target bitrate in bits per second. Overrides `quality` when set. `-1` to use quality preset. */
  bitrate: number;
  /** Target width in pixels. `-1` to keep original. Height is auto-calculated to preserve aspect ratio. */
  width: number;
  /** Target height in pixels. `-1` to keep original. Width is auto-calculated to preserve aspect ratio. */
  height: number;
  /** Target frame rate. `-1` to keep original. */
  frameRate: number;
  /** Output file extension (e.g. `"mp4"`). Default `"mp4"`. */
  outputExt: string;
  /** When `true`, strips the audio track from the output. Default `false`. */
  removeAudio: boolean;
}

/**
 * Result returned by {@link compress}.
 */
export interface CompressResult {
  /** Absolute path to the compressed output file. */
  outputPath: string;
}

/**
 * Options for converting a video segment to an animated GIF.
 */
export interface GifOptions {
  /** Start time in milliseconds. Default `0`. */
  startTime: number;
  /** End time in milliseconds. Default `-1` (end of video). */
  endTime: number;
  /** Frame rate of the GIF. Default `10`. */
  fps: number;
  /** Width in pixels. Height is auto-calculated to preserve aspect ratio. `-1` for original. */
  width: number;
}

/**
 * Result returned by {@link toGif}.
 */
export interface GifResult {
  /** Absolute path to the generated GIF file. */
  outputPath: string;
}

/**
 * Options for merging multiple media files into one.
 */
export interface MergeOptions {
  /** Output file extension (e.g. `"mp4"`, `"wav"`). Default `"mp4"`. */
  outputExt: string;
  /**
   * When `true`, the output has no audio track. Default `false`. Clips without
   * an audio track are accepted either way: if none of them has audio, the
   * output is video-only; otherwise each silent clip is filled with silence.
   */
  removeAudio: boolean;
}

/**
 * Result returned by {@link merge}.
 */
export interface MergeResult {
  /** Absolute path to the merged output file. */
  outputPath: string;
  /** Total duration of the merged file in milliseconds. */
  duration: number;
}

/**
 * Options for mixing an external audio track (background music / voice-over)
 * into a video.
 */
export interface MixAudioOptions {
  /**
   * Volume multiplier applied to the video's original audio track. `1.0` keeps
   * it unchanged, `0` effectively removes it (replace mode). Default `1.0`.
   */
  originalAudioVolume: number;
  /**
   * Volume multiplier applied to the background audio track. `1.0` is the
   * original level. Default `1.0`.
   */
  backgroundAudioVolume: number;
  /**
   * Delay in milliseconds before the background audio starts, relative to the
   * beginning of the video. Default `0`.
   */
  audioStartTime: number;
  /**
   * When `true`, the background audio is looped to cover the whole video.
   * When `false`, it plays once. The output keeps the video's length either
   * way, except when the video has no audio track and the background audio is
   * shorter: the output then ends with the background audio. Default `false`.
   */
  loopAudio: boolean;
  /** Output file extension (e.g. `"mp4"`). Default `"mp4"`. */
  outputExt: string;
}

/**
 * Result returned by {@link mixAudio}.
 */
export interface MixAudioResult {
  /** Absolute path to the output video file. */
  outputPath: string;
  /** Duration of the output video in milliseconds. */
  duration: number;
}

/**
 * Result returned by {@link saveToPhoto}.
 */
export interface SaveToPhotoResult {
  /** Whether the file was saved to the photo library successfully. */
  success: boolean;
}

/**
 * Result returned by {@link saveToDocuments}.
 */
export interface SaveToDocumentsResult {
  /** Whether the file was saved to documents successfully. */
  success: boolean;
}

/**
 * Result returned by {@link share}.
 */
export interface ShareResult {
  /** Whether the user completed the share action. */
  success: boolean;
}

/**
 * TurboModule spec for the native `VideoTrim` module, and the type of the
 * package's default export.
 *
 * Prefer the named functions (they fill in defaults and convert colors) for
 * calling methods. Use the `on*` emitters on the default export to subscribe
 * to editor events on the New Architecture; see `VideoTrimEventMap` for the
 * payloads.
 */
export interface Spec extends TurboModule {
  /** Open the trimmer editor for the given video or audio file. */
  showEditor(filePath: string, config: EditorConfig): void;
  /** List all output files generated by past trim operations. */
  listFiles(): Promise<string[]>;
  /** Delete all output files generated by past trim operations. Returns the number of files removed. */
  cleanFiles(): Promise<number>;
  /**
   * Delete a single file at the given path. Resolves `true` on success. On
   * Android, paths outside the library's output directories resolve `false`.
   */
  deleteFile(filePath: string): Promise<boolean>;
  /** Programmatically close the editor if it is currently open. */
  closeEditor(): void;
  /** Check whether the given URL points to a valid audio or video file. */
  isValidFile(url: string): Promise<FileValidationResult>;
  /** Perform a headless trim (no UI) on the given URL with the specified options. */
  trim(url: string, options: TrimOptions): Promise<TrimResult>;
  /** Extract a single frame from a video at the specified timestamp. */
  getFrameAt(
    url: string,
    options: FrameExtractionOptions
  ): Promise<FrameResult>;
  /** Extract the audio track from a video file into a separate audio file. */
  extractAudio(
    url: string,
    options: ExtractAudioOptions
  ): Promise<ExtractAudioResult>;
  /** Compress a video file to reduce its size. */
  compress(url: string, options: CompressOptions): Promise<CompressResult>;
  /** Convert a video segment to an animated GIF. */
  toGif(url: string, options: GifOptions): Promise<GifResult>;
  /** Merge multiple media files into a single file. Headless only, no editor UI. */
  merge(
    urls: ReadonlyArray<string>,
    options: MergeOptions
  ): Promise<MergeResult>;
  /**
   * Mix (or replace) an external audio track into a video. Headless only, no
   * editor UI. The video stream is copied unchanged; only audio is re-encoded.
   */
  mixAudio(
    videoPath: string,
    audioPath: string,
    options: MixAudioOptions
  ): Promise<MixAudioResult>;
  /** Save a file to the device's photo library. Requires photo library permission. */
  saveToPhoto(filePath: string): Promise<SaveToPhotoResult>;
  /** Present the system document picker to save a file to the user's chosen location. */
  saveToDocuments(filePath: string): Promise<SaveToDocumentsResult>;
  /** Open the system share sheet for a file. */
  share(filePath: string): Promise<ShareResult>;

  /** Emitted when the trim operation starts. */
  readonly onStartTrimming: EventEmitter<void>;
  /** Emitted when the user cancels an in-progress trim operation. */
  readonly onCancelTrimming: EventEmitter<void>;
  /** Emitted when the user dismisses the editor without trimming. */
  readonly onCancel: EventEmitter<void>;
  /** Emitted when the editor is hidden. */
  readonly onHide: EventEmitter<void>;
  /** Emitted when the editor is shown. */
  readonly onShow: EventEmitter<void>;
  /** Emitted when trimming completes successfully. All time values are in milliseconds. */
  readonly onFinishTrimming: EventEmitter<{
    /** Absolute path to the trimmed output file. */
    outputPath: string;
    /** Start time of the trimmed range in milliseconds. */
    startTime: number;
    /** End time of the trimmed range in milliseconds. */
    endTime: number;
    /** Duration of the trimmed clip in milliseconds. */
    duration: number;
  }>;
  /** Emitted with FFmpeg log output during trimming. */
  readonly onLog: EventEmitter<{
    level: string;
    message: string;
    sessionId: number;
  }>;
  /** Emitted with FFmpeg encoding statistics during trimming. */
  readonly onStatistics: EventEmitter<{
    sessionId: number;
    videoFrameNumber: number;
    videoFps: number;
    videoQuality: number;
    size: number;
    time: number;
    bitrate: number;
    speed: number;
  }>;
  /** Emitted when loading, trimming or saving fails. */
  readonly onError: EventEmitter<{
    message: string;
    errorCode: string;
  }>;
  /** Emitted when the media file has finished loading in the editor. */
  readonly onLoad: EventEmitter<{
    /** Duration of the loaded media in milliseconds. */
    duration: number;
  }>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('VideoTrim');
