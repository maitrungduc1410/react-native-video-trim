import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';
import type { EventEmitter } from 'react-native/Libraries/Types/CodegenTypes';

export interface BaseOptions {
  saveToPhoto: boolean;
  type: string;
  outputExt: string;
  removeAfterSavedToPhoto: boolean;
  removeAfterFailedToSavePhoto: boolean;
  enableRotation: boolean;
  rotationAngle: number;
}

export interface EditorConfig extends BaseOptions {
  enableHapticFeedback: boolean;
  maxDuration: number;
  minDuration: number;
  openDocumentsOnFinish: boolean;
  openShareSheetOnFinish: boolean;
  removeAfterSavedToDocuments: boolean;
  removeAfterFailedToSaveDocuments: boolean;
  removeAfterShared: boolean;
  removeAfterFailedToShare: boolean;
  cancelButtonText: string;
  saveButtonText: string;
  enableCancelDialog: boolean;
  cancelDialogTitle: string;
  cancelDialogMessage: string;
  cancelDialogCancelText: string;
  cancelDialogConfirmText: string;
  enableSaveDialog: boolean;
  saveDialogTitle: string;
  saveDialogMessage: string;
  saveDialogCancelText: string;
  saveDialogConfirmText: string;
  trimmingText: string;
  fullScreenModalIOS: boolean;
  autoplay: boolean;
  jumpToPositionOnLoad: number;
  closeWhenFinish: boolean;
  enableCancelTrimming: boolean;
  cancelTrimmingButtonText: string;
  enableCancelTrimmingDialog: boolean;
  cancelTrimmingDialogTitle: string;
  cancelTrimmingDialogMessage: string;
  cancelTrimmingDialogCancelText: string;
  cancelTrimmingDialogConfirmText: string;
  headerText: string;
  headerTextSize: number;
  headerTextColor: number;
  alertOnFailToLoad: boolean;
  alertOnFailTitle: string;
  alertOnFailMessage: string;
  alertOnFailCloseText: string;
  /**
   * Android only
   * Update status bar to black background color when editor is opened
   */
  changeStatusBarColorOnOpen?: boolean;
  /**
   * Color of the trimmer bar
   */
  trimmerColor?: number;
  /**
   * Color of the trimmer left/right handle icons
   */
  handleIconColor?: number;
  /**
   * Duration for zoom-on-waiting feature in milliseconds (default: 5000)
   * When user pauses while dragging trim handles, the view will zoom to show
   * this duration around the current trim position for more precise editing
   */
  zoomOnWaitingDuration?: number;
}

export interface TrimOptions extends BaseOptions {
  startTime: number;
  endTime: number;
}

export interface FileValidationResult {
  isValid: boolean;
  fileType: string;
  duration: number;
}

export interface Spec extends TurboModule {
  showEditor(filePath: string, config: EditorConfig): void;
  listFiles(): Promise<string[]>;
  cleanFiles(): Promise<number>;
  deleteFile(filePath: string): Promise<boolean>;
  closeEditor(): void;
  isValidFile(url: string): Promise<FileValidationResult>;
  trim(url: string, options: TrimOptions): Promise<string>;

  readonly onStartTrimming: EventEmitter<void>;
  readonly onCancelTrimming: EventEmitter<void>;
  readonly onCancel: EventEmitter<void>;
  readonly onHide: EventEmitter<void>;
  readonly onShow: EventEmitter<void>;
  readonly onFinishTrimming: EventEmitter<{
    outputPath: string;
    startTime: number;
    endTime: number;
    duration: number;
  }>;
  readonly onLog: EventEmitter<{
    level: string;
    message: string;
    sessionId: number;
  }>;
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
  readonly onError: EventEmitter<{
    message: string;
    errorCode: string;
  }>;
  readonly onLoad: EventEmitter<{
    duration: number;
  }>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('VideoTrim');
