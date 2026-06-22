package com.videotrim.utils

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.graphics.RectF
import android.media.MediaMetadataRetriever
import android.util.Log
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegSession
import com.arthenica.ffmpegkit.ReturnCode
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.bridge.WritableMap
import com.videotrim.enums.ErrorCode
import com.videotrim.interfaces.VideoTrimListener
import iknow.android.utils.DeviceUtil
import iknow.android.utils.UnitConverter
import iknow.android.utils.callback.SingleCallback
import iknow.android.utils.thread.BackgroundExecutor
import java.text.SimpleDateFormat
import java.util.Date
import java.util.TimeZone
import kotlin.math.roundToInt

/**
 * Handle returned from FFmpeg trim invocations that own an encoder-fallback chain.
 *
 * A single trim request may span multiple FFmpeg sessions when the first encoder
 * (typically [h264_mediacodec]) fails at configure-time on a quirky hardware
 * encoder and we retry with a software fallback. The handle tracks the currently
 * running session so callers can cancel without caring which attempt is active.
 */
class TrimSession {
  @Volatile private var currentSession: FFmpegSession? = null
  @Volatile internal var cancelled = false

  internal fun setCurrentSession(session: FFmpegSession?) {
    currentSession = session
  }

  fun cancel() {
    cancelled = true
    currentSession?.cancel()
  }
}

object VideoTrimmerUtil {

  private val TAG: String = VideoTrimmerUtil::class.java.simpleName
  const val FILE_PREFIX = "trimmedVideo"
  const val MIN_SHOOT_DURATION = 1000L
  const val VIDEO_MAX_TIME = 10
  const val MAX_SHOOT_DURATION = VIDEO_MAX_TIME * 1000L
  @JvmField var MAX_COUNT_RANGE = 10
  @JvmField var SCREEN_WIDTH_FULL = DeviceUtil.getDeviceWidth()
  @JvmField val RECYCLER_VIEW_PADDING = UnitConverter.dpToPx(35)
  const val DEFAULT_AUDIO_EXTENSION = ".wav"
  @JvmField var VIDEO_FRAMES_WIDTH = SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2
  @JvmField var mThumbWidth = 0
  @JvmField val THUMB_HEIGHT = UnitConverter.dpToPx(50)
  @JvmField val THUMB_WIDTH = UnitConverter.dpToPx(25)
  private const val THUMB_RESOLUTION_RES = 2

  internal fun buildAtempoChain(speed: Double): String {
    var remaining = speed
    val filters = mutableListOf<String>()
    while (remaining < 0.5) {
      filters.add("atempo=0.5")
      remaining /= 0.5
    }
    while (remaining > 2.0) {
      filters.add("atempo=2.0")
      remaining /= 2.0
    }
    filters.add("atempo=$remaining")
    return filters.joinToString(",")
  }

  /**
   * Largest dimension (in pixels) we allow on the long side of the frame when
   * falling back to the software `mpeg4` encoder.
   *
   * MPEG-4 Part 2 *encoding* succeeds at any resolution, but Android only ships
   * a software MPEG-4 Part 2 *decoder* (e.g. `OMX.qti.video.decoder.mpeg4sw`)
   * whose capabilities top out well below modern phone-capture resolutions.
   * A full-resolution `mpeg4` file (e.g. 1080x2336) therefore encodes fine and
   * even plays back on a desktop, but is rejected on-device and in ExoPlayer/
   * Expo with `format_supported=NO_EXCEEDS_CAPABILITIES` / `Decoder init
   * failed`. Capping the long side to 1280 keeps the macroblock count inside
   * what these software decoders accept (≈720p territory) so the fallback
   * output is actually playable on the device that produced it.
   *
   * This cap is ONLY applied on the `mpeg4` attempt. The hardware
   * `h264_mediacodec` attempt — the common case — keeps the native resolution.
   */
  const val MPEG4_FALLBACK_MAX_LONG_SIDE = 1280

  /**
   * A single attempt in the encoder fallback chain: the encoder argv fragment
   * (e.g. `-c:v h264_mediacodec -b:v 8000000`) plus an optional resolution cap.
   *
   * When [maxLongSide] is non-null, the call site must downscale so the frame's
   * longer edge does not exceed it (see [capLongSideFilter] for `-vf` paths and
   * [capDimensionsToLongSide] for `-filter_complex` paths). When null, the
   * attempt keeps the source resolution.
   */
  internal data class EncoderConfig(
    val args: List<String>,
    val maxLongSide: Int? = null,
  ) {
    /**
     * Human-readable name of the video encoder this attempt uses, parsed from
     * the `-c:v <encoder>` pair. Returns `"copy"` for the stream-copy path
     * (empty [args]). Used purely for logging which path was selected.
     */
    val videoEncoder: String
      get() {
        val idx = args.indexOf("-c:v")
        return if (idx >= 0 && idx + 1 < args.size) args[idx + 1] else "copy"
      }
  }

  /**
   * Encoder fallback chain used when a re-encode is required. Tried in order
   * until one succeeds at FFmpeg's configure() step.
   *
   *  1. `h264_mediacodec` — Android's hardware H.264 encoder. Fastest and the
   *     default. Keeps native resolution. Fails on some quirky Qualcomm/MediaTek
   *     implementations with `MediaCodec configure failed` (see "Android encoder
   *     compatibility" in README).
   *  2. `hevc_mediacodec` — Android's hardware H.265/HEVC encoder. Lives in a
   *     different MediaCodec/OMX component than the H.264 one, so on devices
   *     whose H.264 encoder is broken (e.g. LG G8 ThinQ) the HEVC encoder often
   *     still configures. Hardware-fast, keeps native resolution, and HEVC is
   *     hardware-decodable on modern Android *and* iOS (AVPlayer). `-tag:v hvc1`
   *     is set so the MP4 plays on Apple players (which reject the default
   *     `hev1` tag). Available in every FFmpegKit build (MediaCodec is a system
   *     library — no external lib needed).
   *  3. `mpeg4` — software MPEG-4 Part 2 (Simple Profile). Always available in
   *     every FFmpegKit build, succeeds on every device. Used only as a last
   *     resort when both hardware encoders reject the configuration. Downscaled
   *     to [MPEG4_FALLBACK_MAX_LONG_SIDE] on the long side so Android's software
   *     MPEG-4 decoder can actually play it back (see that constant's docs).
   *
   * The chain only matters for the re-encode branch (transform/crop/precise/
   * speed); the default stream-copy path doesn't open an encoder at all.
   */
  internal fun reEncodeEncoderConfigs(bitrateStr: String): List<EncoderConfig> = listOf(
    EncoderConfig(listOf("-c:v", "h264_mediacodec", "-b:v", bitrateStr)),
    EncoderConfig(listOf("-c:v", "hevc_mediacodec", "-b:v", bitrateStr, "-tag:v", "hvc1")),
    EncoderConfig(
      args = listOf("-c:v", "mpeg4", "-q:v", "3", "-pix_fmt", "yuv420p"),
      maxLongSide = MPEG4_FALLBACK_MAX_LONG_SIDE,
    ),
  )

  /**
   * Build an FFmpeg `scale` filter (for `-vf` chains) that downscales so the
   * frame's longer edge is at most [maxLongSide], preserving aspect ratio and
   * never upscaling. Both output dimensions are forced even (`-2`) as required
   * by the `mpeg4`/H.264 encoders.
   *
   * The conditional handles either orientation: for landscape (`iw > ih`) the
   * width is clamped and the height auto-computed; for portrait/square the
   * height is clamped and the width auto-computed.
   */
  internal fun capLongSideFilter(maxLongSide: Int): String =
    "scale='if(gt(iw,ih),min($maxLongSide,iw),-2)':'if(gt(iw,ih),-2,min($maxLongSide,ih))'"

  /**
   * Clamp explicit pixel [width]/[height] so the longer side is at most
   * [maxLongSide], preserving aspect ratio, never upscaling, and keeping both
   * dimensions even. Used by paths that scale via `-filter_complex` with fixed
   * target dimensions (e.g. [BaseVideoTrimModule.merge]) where a `-vf` cap can't
   * be appended.
   */
  internal fun capDimensionsToLongSide(width: Int, height: Int, maxLongSide: Int): Pair<Int, Int> {
    if (width <= 0 || height <= 0) return width to height
    val longSide = maxOf(width, height)
    if (longSide <= maxLongSide) {
      return (width and 1.inv()) to (height and 1.inv())
    }
    val scale = maxLongSide.toDouble() / longSide
    val w = ((width * scale).roundToInt() and 1.inv()).coerceAtLeast(2)
    val h = ((height * scale).roundToInt() and 1.inv()).coerceAtLeast(2)
    return w to h
  }

  /**
   * Scan an FFmpeg session's log for signatures that indicate the hardware
   * H.264 encoder (MediaCodec) refused to configure on this device. These
   * lines come from FFmpeg's mediacodec wrapper:
   *
   *   `[amediacodec @ ...] android.media.MediaCodec$CodecException: Error 0xffffffc3`
   *   `[h264_mediacodec @ ...] MediaCodec configure failed, Generic error in an external library`
   *
   * When this happens we re-issue the command with the next encoder in the
   * fallback chain instead of surfacing the failure to the user.
   */
  internal fun classifyFFmpegError(session: FFmpegSession): ErrorCode {
    val logs = try { session.allLogsAsString ?: "" } catch (_: Exception) { "" }
    val hardwareEncoderSignals = listOf(
      "MediaCodec configure failed",
      "Error initializing output stream",
    )
    val matchedHardwareSignal = hardwareEncoderSignals.any { logs.contains(it) }
    if (matchedHardwareSignal && logs.contains("mediacodec")) {
      return ErrorCode.HARDWARE_ENCODER_FAILED
    }
    return ErrorCode.TRIMMING_FAILED
  }

  /**
   * Callbacks used by [executeWithEncoderFallback]. Per-attempt log and
   * statistics are forwarded as-is; the success/cancel/error callbacks fire
   * exactly once for the overall trim request after the fallback chain
   * settles.
   *
   * The error callback receives a default message ("Command failed with
   * state ... and rc ...") plus the final attempt's [FFmpegSession] so
   * callers that surface custom error formats (e.g. headless APIs that
   * include `allLogsAsString` in the Promise rejection) can build their
   * own message instead. Pass `null`-safe access since the session may be
   * unavailable in edge cases.
   */
  internal class TrimCallbacks(
    val onLog: (WritableMap) -> Unit,
    val onStatistics: (WritableMap) -> Unit,
    val onProgress: (Int) -> Unit,
    val onSuccess: () -> Unit,
    val onCancel: () -> Unit,
    val onError: (message: String, code: ErrorCode, session: FFmpegSession?) -> Unit,
  )

  /**
   * Execute an FFmpeg trim command with an encoder-fallback chain.
   *
   * The command is built lazily per attempt by [buildCommand], which receives
   * the current encoder args (e.g. `-c:v h264_mediacodec -b:v 8000000`) and
   * returns the full argv. This lets each attempt swap only the encoder
   * portion while reusing the same input/filter/output args.
   *
   * On non-success non-cancel completion, the session log is scanned via
   * [classifyFFmpegError]. If it looks like a hardware encoder rejection and
   * there are more encoders in the chain, we silently retry. Otherwise the
   * error is surfaced via [TrimCallbacks.onError] with the classified code.
   *
   * Returns a [TrimSession] handle whose [TrimSession.cancel] cancels the
   * currently running attempt and prevents any further attempts.
   */
  internal fun executeWithEncoderFallback(
    encoderConfigs: List<EncoderConfig>,
    buildCommand: (config: EncoderConfig) -> Array<String>,
    videoDurationMs: Int,
    callbacks: TrimCallbacks,
  ): TrimSession {
    val trimSession = TrimSession()
    runAttempt(trimSession, encoderConfigs.iterator(), buildCommand, videoDurationMs, callbacks)
    return trimSession
  }

  private fun runAttempt(
    trimSession: TrimSession,
    encoderIterator: Iterator<EncoderConfig>,
    buildCommand: (config: EncoderConfig) -> Array<String>,
    videoDurationMs: Int,
    callbacks: TrimCallbacks,
  ) {
    if (trimSession.cancelled) {
      UiThreadUtil.runOnUiThread { callbacks.onCancel() }
      return
    }
    if (!encoderIterator.hasNext()) {
      // Should be unreachable: a non-retryable error (or the last rung's failure)
      // is surfaced via onError below before the iterator is exhausted here.
      UiThreadUtil.runOnUiThread {
        callbacks.onError("Encoder fallback chain exhausted", ErrorCode.TRIMMING_FAILED, null)
      }
      return
    }

    val encoderConfig = encoderIterator.next()
    val selectedEncoder = encoderConfig.videoEncoder
    val command = buildCommand(encoderConfig)

    // Log which encoder path was selected for this attempt. Emitted through both
    // logcat (TAG) and the onLog channel so it shows up in `adb logcat` and in
    // JS (Metro) for the editor/trim paths — useful for debugging which encoder a
    // given device actually used (h264_mediacodec / hevc_mediacodec / mpeg4 / copy).
    val capNote = encoderConfig.maxLongSide?.let { " (downscaled to ${it}px long side)" } ?: ""
    val selectionMsg = "Encoder selected: $selectedEncoder$capNote"
    Log.d(TAG, selectionMsg)
    val selMap = Arguments.createMap()
    selMap.putString("message", selectionMsg)
    callbacks.onLog(selMap)

    val cmdStr = "Command: ${command.joinToString(" ")}"
    Log.d(TAG, cmdStr)
    val cmdMap = Arguments.createMap()
    cmdMap.putString("message", cmdStr)
    callbacks.onLog(cmdMap)

    val session = FFmpegKit.executeWithArgumentsAsync(command, { session ->
      val state = session.state
      val returnCode = session.returnCode
      UiThreadUtil.runOnUiThread {
        when {
          ReturnCode.isSuccess(returnCode) -> {
            val successMsg = "Encoder succeeded: $selectedEncoder$capNote"
            Log.d(TAG, successMsg)
            val okMap = Arguments.createMap()
            okMap.putString("message", successMsg)
            callbacks.onLog(okMap)
            callbacks.onSuccess()
          }
          ReturnCode.isCancel(returnCode) -> callbacks.onCancel()
          else -> {
            val classified = classifyFFmpegError(session)
            // Retry the next rung when either (a) the log carries a hardware-encoder
            // signature, or (b) this attempt used a hardware MediaCodec encoder at all
            // — the latter guarantees we still reach the software `mpeg4` floor on
            // devices whose failure log doesn't match a known signature (e.g. a device
            // with no HEVC encoder). Software `mpeg4` failures are never retried.
            val hardwareAttempt = selectedEncoder.endsWith("_mediacodec")
            val shouldFallback =
              (classified == ErrorCode.HARDWARE_ENCODER_FAILED || hardwareAttempt) &&
                encoderIterator.hasNext()
            if (shouldFallback) {
              // Log the fallback decision via the existing onLog channel (and logcat)
              // so consumers can observe which encoder failed and that a fallback —
              // with possible quality/resolution degradation — is being attempted.
              val noticeMsg =
                "Encoder '$selectedEncoder' failed to configure; falling back to next encoder in chain"
              Log.d(TAG, noticeMsg)
              val notice = Arguments.createMap()
              notice.putString("message", noticeMsg)
              callbacks.onLog(notice)
              runAttempt(trimSession, encoderIterator, buildCommand, videoDurationMs, callbacks)
            } else {
              val errorMessage =
                "Command failed with state $state and rc $returnCode.${session.failStackTrace}"
              Log.d(TAG, "Encoder '$selectedEncoder' failed (no further fallback): $errorMessage")
              callbacks.onError(errorMessage, classified, session)
            }
          }
        }
      }
    }, { log ->
      Log.d(TAG, "FFmpeg process started with log ${log.message}")
      val map = Arguments.createMap()
      map.putInt("level", log.level.value)
      map.putString("message", log.message)
      map.putDouble("sessionId", log.sessionId.toDouble())
      map.putString("logStr", log.toString())
      UiThreadUtil.runOnUiThread { callbacks.onLog(map) }
    }, { statistics ->
      val timeInMilliseconds = statistics.time.toInt()
      if (timeInMilliseconds > 0 && videoDurationMs > 0) {
        val completePercentage = (timeInMilliseconds * 100) / videoDurationMs
        UiThreadUtil.runOnUiThread {
          callbacks.onProgress(completePercentage.coerceIn(0, 100))
        }
      }
      val map = Arguments.createMap()
      map.putDouble("sessionId", statistics.sessionId.toDouble())
      map.putInt("videoFrameNumber", statistics.videoFrameNumber)
      map.putDouble("videoFps", statistics.videoFps.toDouble())
      map.putDouble("videoQuality", statistics.videoQuality.toDouble())
      map.putDouble("size", statistics.size.toDouble())
      map.putDouble("time", statistics.time)
      map.putDouble("bitrate", statistics.bitrate.toDouble())
      map.putDouble("speed", statistics.speed.toDouble())
      map.putString("statisticsStr", statistics.toString())
      UiThreadUtil.runOnUiThread { callbacks.onStatistics(map) }
    })

    trimSession.setCurrentSession(session)

    // If cancel arrived between the iterator check and session start, cancel
    // immediately so the FFmpeg session won't run to completion.
    if (trimSession.cancelled) {
      session.cancel()
    }
  }

  fun trim(
    inputFile: String,
    outputFile: String,
    videoDuration: Int,
    startMs: Long,
    endMs: Long,
    userRotationCount: Int,
    userIsFlipped: Boolean,
    cropNormalized: RectF?,
    videoWidth: Int,
    videoHeight: Int,
    videoBitrate: Long,
    enablePreciseTrimming: Boolean,
    removeAudio: Boolean,
    speed: Double,
    callback: VideoTrimListener
  ): TrimSession {
    val currentDate = Date()
    @SuppressLint("SimpleDateFormat")
    val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
    dateFormat.timeZone = TimeZone.getTimeZone("UTC")
    val formattedDateTime = dateFormat.format(currentDate)

    val hasUserTransform = userRotationCount != 0 || userIsFlipped
    // Re-encode is required when: (1) user applied flip/rotate, (2) user cropped, or
    // (3) enablePreciseTrimming is on, or (4) speed != 1.0. In those cases, -c copy
    // won't work because either we need video filters or we need frame-accurate cut points.
    val needsReEncode = hasUserTransform || cropNormalized != null || enablePreciseTrimming || speed != 1.0

    val callbacks = TrimCallbacks(
      onLog = { callback.onLog(it) },
      onStatistics = { callback.onStatistics(it) },
      onProgress = { callback.onTrimmingProgress(it) },
      onSuccess = { callback.onFinishTrim(outputFile, startMs, endMs, videoDuration) },
      onCancel = { callback.onCancelTrim() },
      onError = { msg, code, _ -> callback.onError(msg, code) },
    )

    if (!needsReEncode) {
      // Stream copy: no re-encoding, extremely fast but only cuts at keyframes.
      // No encoder is opened so the fallback chain doesn't apply — single attempt.
      // -y overwrites any pre-existing output file without prompting.
      val cmds = mutableListOf("-y", "-ss", "${startMs}ms", "-to", "${endMs}ms", "-i", inputFile)
      if (removeAudio) {
        cmds.addAll(listOf("-c:v", "copy", "-an"))
      } else {
        cmds.addAll(listOf("-c", "copy"))
      }
      cmds.addAll(listOf("-metadata", "creation_time=$formattedDateTime", outputFile))
      return executeWithEncoderFallback(
        encoderConfigs = listOf(EncoderConfig(emptyList())),
        buildCommand = { cmds.toTypedArray() },
        videoDurationMs = videoDuration,
        callbacks = callbacks,
      )
    }

    // Build the video filters once. They're encoder-independent.
    val videoFilters = mutableListOf<String>()
    when (userRotationCount) {
      1 -> videoFilters.add("transpose=2")
      2 -> { videoFilters.add("transpose=2"); videoFilters.add("transpose=2") }
      3 -> videoFilters.add("transpose=1")
    }
    if (userIsFlipped) {
      videoFilters.add("hflip")
    }
    // Convert normalized crop rect [0..1] to pixel coordinates in the post-rotation frame.
    if (cropNormalized != null && videoWidth > 0 && videoHeight > 0) {
      val postW: Int
      val postH: Int
      // After 90°/270° rotation the width and height are swapped.
      if (userRotationCount % 2 != 0) {
        postW = videoHeight; postH = videoWidth
      } else {
        postW = videoWidth; postH = videoHeight
      }
      val cx = (cropNormalized.left * postW).roundToInt()
      val cy = (cropNormalized.top * postH).roundToInt()
      var cw = (cropNormalized.width() * postW).roundToInt()
      var ch = (cropNormalized.height() * postH).roundToInt()
      // H.264 requires even dimensions; round down to nearest even number.
      cw = cw and 1.inv()
      ch = ch and 1.inv()
      if (cw > 0 && ch > 0) {
        videoFilters.add("crop=$cw:$ch:$cx:$cy")
      }
    }
    if (speed != 1.0) {
      videoFilters.add("setpts=${1.0 / speed}*PTS")
    }

    // Preserve source quality by matching the original bitrate. Falls back to 10 Mbps.
    val bitrateStr = if (videoBitrate > 0) "$videoBitrate" else "10M"

    // Note: Android FFmpegKit auto-rotates by default, so no -noautorotate is needed.
    // The transpose filters above only handle user-initiated rotation, not source metadata.
    val buildCommand: (EncoderConfig) -> Array<String> = { config ->
      // -y overwrites the output file without prompting. This is critical for the
      // encoder fallback chain: the first (hardware) attempt opens/creates the output
      // file before MediaCodec fails, so the software retry reuses the same path and
      // would otherwise hit FFmpeg's interactive "Overwrite? [y/N]" prompt and abort.
      val cmds = mutableListOf("-y", "-ss", "${startMs}ms", "-to", "${endMs}ms", "-i", inputFile)
      // Per-attempt filter chain: the source-driven transforms plus, on the mpeg4
      // software fallback only, a resolution cap so the output is decodable on-device.
      val attemptFilters = videoFilters.toMutableList()
      config.maxLongSide?.let { attemptFilters.add(capLongSideFilter(it)) }
      // When enablePreciseTrimming is the only reason for re-encode (no transforms)
      // and no cap applies, attemptFilters is empty — skip -vf entirely to avoid
      // an FFmpeg error on an empty filter.
      if (attemptFilters.isNotEmpty()) {
        cmds.addAll(listOf("-vf", attemptFilters.joinToString(",")))
      }
      cmds.addAll(config.args)
      when {
        removeAudio -> cmds.add("-an")
        speed != 1.0 -> cmds.addAll(listOf("-af", buildAtempoChain(speed)))
        else -> cmds.addAll(listOf("-c:a", "copy"))
      }
      cmds.addAll(listOf("-metadata", "creation_time=$formattedDateTime", outputFile))
      cmds.toTypedArray()
    }

    return executeWithEncoderFallback(
      encoderConfigs = reEncodeEncoderConfigs(bitrateStr),
      buildCommand = buildCommand,
      videoDurationMs = videoDuration,
      callbacks = callbacks,
    )
  }

  fun shootVideoThumbInBackground(
    mediaMetadataRetriever: MediaMetadataRetriever,
    totalThumbsCount: Int,
    startPosition: Long,
    endPosition: Long,
    callback: SingleCallback<Bitmap, Int>
  ) {
    BackgroundExecutor.execute(object : BackgroundExecutor.Task("initial_thumbs", 0L, "") {
      override fun execute() {
        try {
          val interval = (endPosition - startPosition) / (totalThumbsCount - 1)
          for (i in 0 until totalThumbsCount) {
            val frameTime = startPosition + interval * i

            val bitmap: Bitmap? = try {
              mediaMetadataRetriever.getFrameAtTime(frameTime * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            } catch (t: Throwable) {
              t.printStackTrace()
              break
            }

            if (bitmap == null) continue
            val scaledBitmap = try {
              Bitmap.createScaledBitmap(bitmap, mThumbWidth * THUMB_RESOLUTION_RES, THUMB_HEIGHT * THUMB_RESOLUTION_RES, false)
            } catch (t: Throwable) {
              t.printStackTrace()
              bitmap
            }
            callback.onSingleCallback(scaledBitmap, interval.toInt())
          }
        } catch (e: Throwable) {
          Thread.getDefaultUncaughtExceptionHandler()?.uncaughtException(Thread.currentThread(), e)
        }
      }
    })
  }
}