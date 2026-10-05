import type { EventEmitter } from 'react-native/Libraries/Types/CodegenTypes';
import type { EditorConfig, Spec } from './NativeVideoTrim';

/**
 * Options accepted by {@link showEditor}. Every field is optional; anything you
 * leave out falls back to its default.
 *
 * This is {@link EditorConfig} with the color fields taking any React Native
 * color string (`'#f1d247'`, `'red'`, `'rgba(0,0,0,0.5)'`) instead of a
 * `processColor` number.
 *
 * @example
 * ```ts
 * const options: EditorOptions = {
 *   maxDuration: 30_000,
 *   theme: 'light',
 *   trimmerColor: '#007AFF',
 * };
 * showEditor(videoPath, options);
 * ```
 */
export type EditorOptions = Partial<
  Omit<
    EditorConfig,
    | 'headerTextColor'
    | 'trimmerColor'
    | 'handleIconColor'
    | 'waveformColor'
    | 'waveformBackgroundColor'
  >
> & {
  /** Header text color. Defaults to white in the dark theme, black in the light theme. */
  headerTextColor?: string;
  /** Trimmer bar color. Default `'#f1d247'`. */
  trimmerColor?: string;
  /** Color of the chevrons on the trimmer handles. Defaults to black in the dark theme, white in the light theme. */
  handleIconColor?: string;
  /** Audio waveform bar color. Default `'white'`. */
  waveformColor?: string;
  /** Background behind the audio waveform bars. Default `'#3478F6'`. */
  waveformBackgroundColor?: string;
};

/** Payload of the `onLoad` event. */
export interface LoadEvent {
  /** Duration of the loaded media in milliseconds. */
  duration: number;
}

/** Payload of the `onFinishTrimming` event. All times are in milliseconds. */
export interface FinishTrimmingEvent {
  /** Absolute path to the trimmed output file. */
  outputPath: string;
  /** Start time of the trimmed range in milliseconds. */
  startTime: number;
  /** End time of the trimmed range in milliseconds. */
  endTime: number;
  /** Duration of the trimmed clip in milliseconds. */
  duration: number;
}

/** Payload of the `onLog` event: one FFmpeg log line. */
export interface LogEvent {
  /** FFmpeg log level. */
  level: string;
  /** The log message. */
  message: string;
  /** FFmpeg session that produced the line. */
  sessionId: number;
}

/** Payload of the `onStatistics` event: FFmpeg encoding progress. */
export interface StatisticsEvent {
  /** FFmpeg session the statistics belong to. */
  sessionId: number;
  /** Number of video frames processed so far. */
  videoFrameNumber: number;
  /** Current encoding speed in frames per second. */
  videoFps: number;
  /** Current video quality reported by the encoder. */
  videoQuality: number;
  /** Output size so far, in bytes. */
  size: number;
  /** Position reached in the output, in milliseconds. */
  time: number;
  /** Current output bitrate. */
  bitrate: number;
  /** Processing speed relative to real time. */
  speed: number;
}

/**
 * Error codes the native code reports in {@link VideoTrimErrorEvent.errorCode}.
 * Not every code is emitted on both platforms, and new codes may be added, so
 * always handle unknown values.
 */
export type ErrorCode =
  | 'TRIMMING_FAILED'
  | 'HARDWARE_ENCODER_FAILED'
  | 'OUTPUT_FORMAT_INCOMPATIBLE'
  | 'FAIL_TO_LOAD_MEDIA'
  | 'FAIL_TO_SAVE_TO_PHOTO'
  | 'FAIL_TO_SAVE_TO_DOCUMENTS'
  | 'FAIL_TO_SHARE'
  | 'NO_PHOTO_PERMISSION'
  | 'INVALID_FILE_PATH'
  | 'FAIL_TO_GET_VIDEO_INFO'
  | 'FAIL_TO_INITIALIZE_AUDIO_PLAYER'
  | 'UNKNOWN';

/** Payload of the `onError` event. */
export interface VideoTrimErrorEvent {
  /** Human-readable description, often including FFmpeg output. */
  message: string;
  /** Machine-readable error code, usually one of {@link ErrorCode}. */
  errorCode: string;
}

/**
 * Editor events and their payloads. Events without a payload map to `void`.
 *
 * On the New Architecture each key is a method on the default export that
 * subscribes a listener. On the Old Architecture every event arrives as a
 * single native `"VideoTrim"` event, see {@link VideoTrimEvent}.
 */
export interface VideoTrimEventMap {
  /** The editor was presented. */
  onShow: void;
  /** The editor was dismissed. */
  onHide: void;
  /** The media finished loading in the editor. */
  onLoad: LoadEvent;
  /** The user confirmed and trimming started. */
  onStartTrimming: void;
  /** Trimming completed and the output file was written. */
  onFinishTrimming: FinishTrimmingEvent;
  /** The user cancelled a trim that was in progress. */
  onCancelTrimming: void;
  /** The user closed the editor without trimming. */
  onCancel: void;
  /** FFmpeg log output while trimming. */
  onLog: LogEvent;
  /** FFmpeg encoding statistics while trimming. */
  onStatistics: StatisticsEvent;
  /** Loading, trimming or saving failed. */
  onError: VideoTrimErrorEvent;
}

/** Name of an editor event. */
export type VideoTrimEventName = keyof VideoTrimEventMap;

/**
 * Body of the Old Architecture `"VideoTrim"` native event: the event name in
 * `name` plus the fields of that event's payload. Narrow it with a `switch` on
 * `name`.
 *
 * @example
 * ```ts
 * const emitter = new NativeEventEmitter(NativeModules.VideoTrim);
 * const sub = emitter.addListener('VideoTrim', (event: VideoTrimEvent) => {
 *   if (event.name === 'onFinishTrimming') console.log(event.outputPath);
 * });
 * ```
 */
export type VideoTrimEvent = {
  [K in VideoTrimEventName]: { name: K } & (VideoTrimEventMap[K] extends void
    ? Record<never, never>
    : VideoTrimEventMap[K]);
}[VideoTrimEventName];

type Payload<E> = E extends EventEmitter<infer T> ? T : never;
type Same<A, B> = [A] extends [B] ? ([B] extends [A] ? true : false) : false;
type Assert<T extends true> = T;

/**
 * Fails to type-check when {@link VideoTrimEventMap} and the emitters on the
 * TurboModule spec drift apart. Not re-exported from the package.
 */
export type EventMapMatchesSpec = Assert<
  {
    [K in VideoTrimEventName]: Same<VideoTrimEventMap[K], Payload<Spec[K]>>;
  } extends Record<VideoTrimEventName, true>
    ? {
        [K in keyof Spec as Spec[K] extends EventEmitter<any>
          ? K
          : never]: K extends VideoTrimEventName ? true : false;
      } extends Record<string, true>
      ? true
      : false
    : false
>;