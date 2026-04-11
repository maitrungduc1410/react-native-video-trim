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
   * only cut at keyframes — the actual start/end may drift by several seconds.
   *
   * Note: if the user applies any transform (flip/rotate/crop), re-encoding already
   * happens regardless of this flag, so precise trimming comes for free in that case.
   */
  enablePreciseTrimming: boolean;
}

/**
 * Configuration for the video trimmer editor UI.
 */
export interface EditorConfig extends BaseOptions {
  /** Whether to enable haptic feedback when interacting with the trimmer. */
  enableHapticFeedback: boolean;
  /** Maximum allowed duration for the trimmed clip in milliseconds. Set to `-1` for no limit. */
  maxDuration: number;
  /** Minimum allowed duration for the trimmed clip in milliseconds. Set to `-1` for no limit. */
  minDuration: number;
  /** Whether to open the system documents/files app after trimming finishes. */
  openDocumentsOnFinish: boolean;
  /** Whether to open the share sheet after trimming finishes. */
  openShareSheetOnFinish: boolean;
  /** Whether to remove the output file after it has been saved to documents. */
  removeAfterSavedToDocuments: boolean;
  /** Whether to remove the output file if saving to documents fails. */
  removeAfterFailedToSaveDocuments: boolean;
  /** Whether to remove the output file after it has been shared. */
  removeAfterShared: boolean;
  /** Whether to remove the output file if sharing fails. */
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
  /** Whether to allow the user to cancel an in-progress trim operation. */
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
   * Duration for the zoom-on-waiting feature in milliseconds (default: `5000`).
   * When the user pauses while dragging trim handles, the view zooms to show
   * this duration around the current trim position for more precise editing.
   */
  zoomOnWaitingDuration?: number;
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
 * Result returned by {@link Spec.isValidFile}.
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
 * TurboModule spec for the native VideoTrim module.
 */
export interface Spec extends TurboModule {
  /** Open the video trimmer editor for the given file. */
  showEditor(filePath: string, config: EditorConfig): void;
  /** List all output files generated by past trim operations. */
  listFiles(): Promise<string[]>;
  /** Delete all output files generated by past trim operations. Returns the number of files removed. */
  cleanFiles(): Promise<number>;
  /** Delete a single file at the given path. Resolves `true` on success. */
  deleteFile(filePath: string): Promise<boolean>;
  /** Programmatically close the editor if it is currently open. */
  closeEditor(): void;
  /** Check whether the given URL points to a valid audio or video file. */
  isValidFile(url: string): Promise<FileValidationResult>;
  /** Perform a headless trim (no UI) on the given URL with the specified options. */
  trim(url: string, options: TrimOptions): Promise<TrimResult>;

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
  /** Emitted when an error occurs during trimming or file loading. */
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
