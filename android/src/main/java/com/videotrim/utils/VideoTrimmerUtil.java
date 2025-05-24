package com.videotrim.utils;

import android.annotation.SuppressLint;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.util.Log;

import com.arthenica.ffmpegkit.FFmpegKit;
import com.arthenica.ffmpegkit.FFmpegSession;
import com.arthenica.ffmpegkit.ReturnCode;
import com.arthenica.ffmpegkit.SessionState;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;
import com.videotrim.enums.ErrorCode;
import com.videotrim.interfaces.VideoTrimListener;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.TimeZone;

import iknow.android.utils.DeviceUtil;
import iknow.android.utils.UnitConverter;
import iknow.android.utils.callback.SingleCallback;
import iknow.android.utils.thread.BackgroundExecutor;

public class VideoTrimmerUtil {

  private static final String TAG = VideoTrimmerUtil.class.getSimpleName();
  public static final String FILE_PREFIX = "trimmedVideo";
  public static final long MIN_SHOOT_DURATION = 1000L;// min 3 seconds for trimming
  public static final int VIDEO_MAX_TIME = 10;// max 10 seconds for trimming
  public static final long MAX_SHOOT_DURATION = VIDEO_MAX_TIME * 1000L;
//  public static long maxShootDuration = 10 * 1000L;
  public static int MAX_COUNT_RANGE = 10;  // how many images in the highlight range of seek bar
  public static int SCREEN_WIDTH_FULL = DeviceUtil.getDeviceWidth();
  public static final int RECYCLER_VIEW_PADDING = UnitConverter.dpToPx(35);
  public static String DEFAULT_AUDIO_EXTENSION = ".wav";
  public static int VIDEO_FRAMES_WIDTH = SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2;
//  public static final int THUMB_WIDTH = (SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2) / VIDEO_MAX_TIME;
  public static int mThumbWidth = 0; // make it automatic
  public static final int THUMB_HEIGHT = UnitConverter.dpToPx(50); // x2 for better resolution
  public static final int THUMB_WIDTH = UnitConverter.dpToPx(25); // x2 for better resolution
  private static final int THUMB_RESOLUTION_RES = 2; // double thumb resolution for better quality

  public static FFmpegSession trim(String inputFile, String outputFile, int videoDuration, long startMs, long endMs, final VideoTrimListener callback) {
    // Get the current date and time
    Date currentDate = new Date();

    // Create a SimpleDateFormat object with the desired format
    @SuppressLint("SimpleDateFormat") SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ");

    // Set the timezone to UTC
    dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
    // Format the current date and time
    String formattedDateTime = dateFormat.format(currentDate);

    String[] cmds = {
      "-ss",
      startMs + "ms",
      "-to",
      endMs + "ms",
      "-i",
      inputFile,
      "-c",
      "copy",
      "-metadata",
      "creation_time=" + formattedDateTime,
      outputFile
    };
    Log.d(TAG,"Command111: " + String.join(",", cmds));

    FFmpegSession s = FFmpegKit.execute("-protocols");
    Log.d(TAG, "1111getOutput: " + s.getOutput());
    Log.d(TAG, "1111getAllLogs: " + s.getAllLogs());

    return FFmpegKit.executeWithArgumentsAsync(cmds, session -> {
      SessionState state = session.getState();
      ReturnCode returnCode = session.getReturnCode();
      if (ReturnCode.isSuccess(session.getReturnCode())) {
        // SUCCESS
        callback.onFinishTrim(outputFile, startMs, endMs, videoDuration);
      } else if (ReturnCode.isCancel(session.getReturnCode())) {
        // CANCEL
        callback.onCancelTrim();
      } else {
        // FAILURE
        String errorMessage = String.format("Command failed with state %s and rc %s.%s", state, returnCode, session.getFailStackTrace());
        callback.onError(errorMessage, ErrorCode.TRIMMING_FAILED);
      }
    }, log -> {
      Log.d(TAG, "FFmpeg process started with log " + log.getMessage());

      WritableMap map = Arguments.createMap();
      map.putInt("level", log.getLevel().getValue());
      map.putString("message", log.getMessage());
      map.putDouble("sessionId", log.getSessionId());
      map.putString("logStr", log.toString());
      callback.onLog(map);
    }, statistics -> {
      int timeInMilliseconds = (int) statistics.getTime();
      if (timeInMilliseconds > 0) {
        int completePercentage =
          (timeInMilliseconds * 100) / videoDuration;
        callback.onTrimmingProgress(Math.min(Math.max(completePercentage, 0), 100));
      }

      WritableMap map = Arguments.createMap();
      map.putDouble("sessionId", statistics.getSessionId());
      map.putInt("videoFrameNumber", statistics.getVideoFrameNumber());
      map.putDouble("videoFps", statistics.getVideoFps());
      map.putDouble("videoQuality", statistics.getVideoQuality());
      map.putDouble("size", statistics.getSize());
      map.putDouble("time", statistics.getTime());
      map.putDouble("bitrate", statistics.getBitrate());
      map.putDouble("speed", statistics.getSpeed());
      map.putString("statisticsStr", statistics.toString());
      callback.onStatistics(map);
    });
  }

  public static void shootVideoThumbInBackground(final MediaMetadataRetriever mediaMetadataRetriever, final int totalThumbsCount, final long startPosition,
                                                 final long endPosition, final SingleCallback<Bitmap, Integer> callback) {
    BackgroundExecutor.execute(new BackgroundExecutor.Task("", 0L, "") {
      @Override public void execute() {
        try {
          // Retrieve media data use microsecond
          long interval = (endPosition - startPosition) / (totalThumbsCount - 1);
          for (long i = 0; i < totalThumbsCount; ++i) {
            long frameTime = startPosition + interval * i;

            Bitmap bitmap;
            try {
              bitmap = mediaMetadataRetriever.getFrameAtTime(frameTime * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
            } catch (final Throwable t) {
              // this can happen while thumbnails are being generated in background and we press Cancel
              t.printStackTrace();
              break;
            }

            if(bitmap == null) continue;
            try {
              bitmap = Bitmap.createScaledBitmap(bitmap, mThumbWidth * THUMB_RESOLUTION_RES, THUMB_HEIGHT * THUMB_RESOLUTION_RES, false);
            } catch (final Throwable t) {
              t.printStackTrace();
            }
            callback.onSingleCallback(bitmap, (int) interval);
          }
        } catch (final Throwable e) {
          Thread.getDefaultUncaughtExceptionHandler().uncaughtException(Thread.currentThread(), e);
        }
      }
    });
  }
}

