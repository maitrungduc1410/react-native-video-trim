package com.videotrim.utils;

import android.content.Context;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import com.arthenica.ffmpegkit.FFmpegKit;
import com.arthenica.ffmpegkit.ReturnCode;
import com.arthenica.ffmpegkit.SessionState;
import com.videotrim.interfaces.VideoTrimListener;
import iknow.android.utils.DeviceUtil;
import iknow.android.utils.UnitConverter;
import iknow.android.utils.callback.SingleCallback;
import iknow.android.utils.thread.BackgroundExecutor;

public class VideoTrimmerUtil {

  private static final String TAG = VideoTrimmerUtil.class.getSimpleName();
  public static final String FILE_PREFIX = "trimmedVideo";
  public static final long MIN_SHOOT_DURATION = 3000L;// min 3 seconds for trimming
//  public static final int VIDEO_MAX_TIME = 10;// max 10 seconds for trimming
//  public static final long MAX_SHOOT_DURATION = VIDEO_MAX_TIME * 1000L;
  public static long maxShootDuration = 10 * 1000L;
  public static int MAX_COUNT_RANGE = 10;  // how many images in the highlight range of seek bar
  public static int SCREEN_WIDTH_FULL = DeviceUtil.getDeviceWidth();
  public static final int RECYCLER_VIEW_PADDING = UnitConverter.dpToPx(35);
  public static int VIDEO_FRAMES_WIDTH = SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2;
//  public static final int THUMB_WIDTH = (SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2) / VIDEO_MAX_TIME;
  public static int mThumbWidth = 0; // make it automatic
  public static final int THUMB_HEIGHT = UnitConverter.dpToPx(50); // x2 for better resolution
  private static final int THUMB_RESOLUTION_RES = 2; // double thumb resolution for better quality

  public static void trim(String inputFile, String outputFile, int videoDuration, long startMs, long endMs, final VideoTrimListener callback) {
    String cmd = "-i " + inputFile + " -ss " + startMs + "ms" + " -to " + endMs + "ms -c copy " + outputFile;
    callback.onStartTrim();
    FFmpegKit.executeAsync(cmd, session -> {
      SessionState state = session.getState();
      ReturnCode returnCode = session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // SUCCESS
        callback.onFinishTrim(outputFile);
      }
      else {
        // CANCEL + FAILURE
        String errorMessage = String.format("Command failed with state %s and rc %s.%s", state, returnCode, session.getFailStackTrace());
        callback.onError(errorMessage);
      }
    }, log -> {

    }, statistics -> {
      int timeInMilliseconds = (int) statistics.getTime();
      if (timeInMilliseconds > 0) {
        int completePercentage =
          (timeInMilliseconds * 100) / videoDuration;
        callback.onTrimmingProgress(Math.min(Math.max(completePercentage, 0), 100));
      }
    });
  }

  public static void shootVideoThumbInBackground(final Context context, final Uri videoUri, final int totalThumbsCount, final long startPosition,
                                                 final long endPosition, final SingleCallback<Bitmap, Integer> callback) {
    BackgroundExecutor.execute(new BackgroundExecutor.Task("", 0L, "") {
      @Override public void execute() {
        try {
          MediaMetadataRetriever mediaMetadataRetriever = new MediaMetadataRetriever();
          mediaMetadataRetriever.setDataSource(context, videoUri);
          // Retrieve media data use microsecond
          long interval = (endPosition - startPosition) / (totalThumbsCount - 1);
          for (long i = 0; i < totalThumbsCount; ++i) {
            long frameTime = startPosition + interval * i;
            Bitmap bitmap = mediaMetadataRetriever.getFrameAtTime(frameTime * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
            if(bitmap == null) continue;
            try {
              bitmap = Bitmap.createScaledBitmap(bitmap, mThumbWidth * THUMB_RESOLUTION_RES, THUMB_HEIGHT * THUMB_RESOLUTION_RES, false);
            } catch (final Throwable t) {
              t.printStackTrace();
            }
            callback.onSingleCallback(bitmap, (int) interval);
          }
          mediaMetadataRetriever.release();
        } catch (final Throwable e) {
          Thread.getDefaultUncaughtExceptionHandler().uncaughtException(Thread.currentThread(), e);
        }
      }
    });
  }
}

