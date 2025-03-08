package com.videotrim.utils;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Bitmap;
import android.media.MediaCodec;
import android.media.MediaMetadataRetriever;
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

import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.os.Handler;
import android.os.Looper;
import java.io.IOException;
import java.nio.ByteBuffer;

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

  private static final int BUFFER_SIZE = 1024 * 1024; // 1MB buffer

  // Custom session class to manage trimming and cancellation
  public static class TrimSession {
    private final Thread trimThread;
    private volatile boolean isCancelled = false;

    private TrimSession(Thread thread) {
      this.trimThread = thread;
    }

    public void cancel() {
      isCancelled = true;
      if (trimThread != null) {
        trimThread.interrupt();
      }
    }

    public boolean isCancelled() {
      return !isCancelled;
    }
  }

  public static TrimSession trim(String inputFile, String outputFile, int videoDuration, long startMs, long endMs, final VideoTrimListener callback, float progressUpdateInterval) {
    // Format creation time
    @SuppressLint("SimpleDateFormat") SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ");
    dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
    String formattedDateTime = dateFormat.format(new Date());

    // Start trimming in a background thread
    Thread trimThread = new Thread(() -> {
      MediaExtractor extractor = null;
      MediaMuxer muxer = null;
//      Handler mainHandler = new Handler(Looper.getMainLooper());
      TrimSession session = new TrimSession(Thread.currentThread());

      try {
        extractor = new MediaExtractor();
        extractor.setDataSource(inputFile);

        int trackCount = extractor.getTrackCount();
        muxer = new MediaMuxer(outputFile, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        int[] trackIndices = new int[trackCount];
        long[] trackStartTimes = new long[trackCount];
        boolean[] tracksAdded = new boolean[trackCount];

        // Select tracks and add to muxer
        for (int i = 0; i < trackCount; i++) {
          MediaFormat format = extractor.getTrackFormat(i);
          trackIndices[i] = muxer.addTrack(format);
          tracksAdded[i] = false;
          extractor.selectTrack(i);
        }

        // Seek to start time
        long startUs = startMs * 1000; // Convert ms to μs
        long endUs = endMs * 1000;
        extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC);

        ByteBuffer buffer = ByteBuffer.allocate(BUFFER_SIZE);
        MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();
        long lastProgressTime = System.currentTimeMillis();

        muxer.start();
        while (session.isCancelled()) {
          bufferInfo.size = extractor.readSampleData(buffer, 0);
          if (bufferInfo.size < 0) break; // EOS

          long sampleTime = extractor.getSampleTime();
          if (sampleTime > endUs) break;

          bufferInfo.presentationTimeUs = sampleTime;
          // Map MediaExtractor flags to MediaCodec flags
          int extractorFlags = extractor.getSampleFlags();
          bufferInfo.flags = (extractorFlags & MediaExtractor.SAMPLE_FLAG_SYNC) != 0 ? MediaCodec.BUFFER_FLAG_KEY_FRAME : 0;
          int trackIndex = extractor.getSampleTrackIndex();

          if (!tracksAdded[trackIndex]) {
            trackStartTimes[trackIndex] = sampleTime;
            tracksAdded[trackIndex] = true;
          }
          bufferInfo.presentationTimeUs -= trackStartTimes[trackIndex]; // Adjust time to start at 0

          muxer.writeSampleData(trackIndices[trackIndex], buffer, bufferInfo);
          extractor.advance();

          // Progress update (every progressUpdateInterval * 1000 ms)
          long currentTime = System.currentTimeMillis();
          if (currentTime - lastProgressTime >= progressUpdateInterval * 1000) {
            double progress = (double)(sampleTime - startUs) / (endUs - startUs);
            if (progress > 0 && progress <= 1) {
              WritableMap statsMap = Arguments.createMap();
              statsMap.putDouble("time", progress * videoDuration);
              statsMap.putDouble("progress", progress); // Percentage

              callback.onStatistics(statsMap);
              callback.onTrimmingProgress((int)(progress * 100));

//              mainHandler.post(() -> callback.onStatistics(statsMap));
//              mainHandler.post(() -> callback.onTrimmingProgress((int)(progress * 100)));

            }
            lastProgressTime = currentTime;
          }
        }

        if (session.isCancelled()) {
          muxer.stop();

          // Update creation_time via MediaStore
//          android.content.ContentResolver contentResolver = context.getContentResolver();
//          android.net.Uri uri = android.provider.MediaStore.Files.getContentUri("external");
//          android.content.ContentValues values = new android.content.ContentValues();
//          values.put(android.provider.MediaStore.MediaColumns.DATA, outputFile);
//          values.put(android.provider.MediaStore.MediaColumns.DATE_ADDED, System.currentTimeMillis() / 1000);
//          values.put(android.provider.MediaStore.MediaColumns.DATE_MODIFIED, System.currentTimeMillis() / 1000);
//          values.put(android.provider.MediaStore.MediaColumns.DATE_TAKEN, System.currentTimeMillis());
//          contentResolver.insert(uri, values);
//          android.content.ContentValues updateValues = new android.content.ContentValues();
//          updateValues.put(android.provider.MediaStore.MediaColumns.DATE_TAKEN, System.currentTimeMillis());
//          contentResolver.update(uri, updateValues, android.provider.MediaStore.MediaColumns.DATA + "=?", new String[]{outputFile});

//          mainHandler.post(() -> callback.onFinishTrim(outputFile, startMs, endMs, videoDuration));
          callback.onFinishTrim(outputFile, startMs, endMs, videoDuration);
        } else {
//          mainHandler.post(callback::onCancelTrim);
          callback.onCancelTrim();
        }

      } catch (IOException e) {
        e.printStackTrace();
//        mainHandler.post(() -> callback.onError("Trimming failed: " + e.getMessage(), ErrorCode.TRIMMING_FAILED));
        callback.onError("Trimming failed: " + e.getMessage(), ErrorCode.TRIMMING_FAILED);
      } finally {
        try {
          if (muxer != null) {
            if (session.isCancelled()) muxer.release();
          }
          if (extractor != null) extractor.release();
        } catch (Exception e) {
          e.printStackTrace();
          System.err.println("Error releasing resources: " + e.getMessage());
        }
      }
    });

    TrimSession session = new TrimSession(trimThread);
    trimThread.start();
    return session;
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

