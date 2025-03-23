package com.videotrim.utils;

import android.graphics.Bitmap;
import android.media.MediaCodec;
import android.media.MediaMetadataRetriever;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;
import com.videotrim.enums.ErrorCode;
import com.videotrim.interfaces.VideoTrimListener;
import iknow.android.utils.DeviceUtil;
import iknow.android.utils.UnitConverter;
import iknow.android.utils.callback.SingleCallback;
import iknow.android.utils.thread.BackgroundExecutor;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMuxer;
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

    public boolean isActive() {
      return !isCancelled;
    }
  }

  public static TrimSession trim(String inputFile, String outputFile, int videoDuration, long startMs, long endMs, final VideoTrimListener callback, float progressUpdateInterval) {
    // Start trimming in a background thread
    Thread trimThread = new Thread(() -> {
      MediaExtractor extractor = null;
      MediaMuxer muxer = null;
      TrimSession session = new TrimSession(Thread.currentThread());

      try {
        // Get rotation metadata from input file
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        retriever.setDataSource(inputFile);
        String rotationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION);
        int rotation = rotationStr != null ? Integer.parseInt(rotationStr) : 0;
        retriever.release();

        extractor = new MediaExtractor();
        extractor.setDataSource(inputFile);

        int trackCount = extractor.getTrackCount();
        muxer = new MediaMuxer(outputFile, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        int[] trackIndices = new int[trackCount];
        long[] trackStartTimes = new long[trackCount];
        boolean[] tracksAdded = new boolean[trackCount];
        int videoTrackIndex = -1;

        // Calculate trimmed duration
        long startUs = startMs * 1000; // e.g., 5s = 5000000us
        long endUs = endMs * 1000;     // e.g., 9s = 9000000us
        long trimmedDurationUs = endUs - startUs; // e.g., 4s = 4000000us

        // Determine max buffer size from video format and resolution
        int maxBufferSize = BUFFER_SIZE; // Default 1MB
        String widthStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH);
        String heightStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT);
        int width = widthStr != null ? Integer.parseInt(widthStr) : 0; // Default to unknown
        int height = heightStr != null ? Integer.parseInt(heightStr) : 0;

        // Adjust buffer size based on resolution
        if (width > 3840 || height > 2160) { // 8K+
          maxBufferSize = 16 * 1024 * 1024; // 16MB for 8K
        } else if (width > 1920 || height > 1080) { // 4K
          maxBufferSize = 8 * 1024 * 1024; // 8MB for 4K
        } else if (width > 1280 || height > 720) { // 1080p
          maxBufferSize = 4 * 1024 * 1024; // 4MB for 1080p
        } // 720p or lower (or unknown resolution) sticks with BUFFER_SIZE (1MB)

        // Add tracks with corrected duration
        for (int i = 0; i < trackCount; i++) {
          MediaFormat format = extractor.getTrackFormat(i);

          // Override with KEY_MAX_INPUT_SIZE if available
          if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
            int maxInputSize = format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE);
            maxBufferSize = Math.max(maxBufferSize, maxInputSize);
          }

          String mime = format.getString(MediaFormat.KEY_MIME);
          if (mime != null && mime.startsWith("video/")) {
            videoTrackIndex = i;
          }
          // Set the duration for each track to the trimmed duration
          format.setLong(MediaFormat.KEY_DURATION, trimmedDurationUs);
          trackIndices[i] = muxer.addTrack(format);
          tracksAdded[i] = false;
          extractor.selectTrack(i);
        }

        // Set rotation metadata on muxer
        muxer.setOrientationHint(rotation);

        // Seek to start time
        extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC);

        ByteBuffer buffer = ByteBuffer.allocate(maxBufferSize);
        MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();
        long lastProgressTime = System.currentTimeMillis();
        boolean videoSampleWritten = false;

        muxer.start();
        while (session.isActive()) {
          bufferInfo.size = extractor.readSampleData(buffer, 0);
          if (bufferInfo.size < 0) break; // EOS

          long sampleTime = extractor.getSampleTime();
          if (sampleTime > endUs) break;

          bufferInfo.presentationTimeUs = sampleTime;
          int extractorFlags = extractor.getSampleFlags();
          bufferInfo.flags = (extractorFlags & MediaExtractor.SAMPLE_FLAG_SYNC) != 0 ? MediaCodec.BUFFER_FLAG_KEY_FRAME : 0;
          int trackIndex = extractor.getSampleTrackIndex();

          if (!tracksAdded[trackIndex]) {
            trackStartTimes[trackIndex] = sampleTime;
            tracksAdded[trackIndex] = true;
          }
          bufferInfo.presentationTimeUs -= trackStartTimes[trackIndex]; // Adjust time to start at 0

          // Ensure presentation time doesn't exceed trimmed duration
          if (bufferInfo.presentationTimeUs >= trimmedDurationUs) {
            extractor.advance();
            continue;
          }

          if (trackIndex == videoTrackIndex) {
            videoSampleWritten = true;
          }
          muxer.writeSampleData(trackIndices[trackIndex], buffer, bufferInfo);
          extractor.advance();

          long currentTime = System.currentTimeMillis();
          if (currentTime - lastProgressTime >= progressUpdateInterval * 1000) {
            double progress = (double)(sampleTime - startUs) / (endUs - startUs);
            if (progress > 0 && progress <= 1) {
              WritableMap statsMap = Arguments.createMap();
              statsMap.putDouble("time", progress * videoDuration);
              statsMap.putDouble("progress", progress); // Percentage

              callback.onStatistics(statsMap);
              callback.onTrimmingProgress((int)(progress * 100));
            }
            lastProgressTime = currentTime;
          }
        }

        // For static videos: ensure one video frame if none written
        if (!videoSampleWritten && videoTrackIndex != -1) {
          for (int i = 0; i < trackCount; i++) {
            if (i != videoTrackIndex) {
              extractor.unselectTrack(i);
            }
          }
          extractor.selectTrack(videoTrackIndex);
          extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC);
          bufferInfo.size = extractor.readSampleData(buffer, 0);
          if (bufferInfo.size >= 0) {
            bufferInfo.presentationTimeUs = 0;
            // Map MediaExtractor flags to MediaCodec flags
            int extractorFlags = extractor.getSampleFlags();
            bufferInfo.flags = (extractorFlags & MediaExtractor.SAMPLE_FLAG_SYNC) != 0 ? MediaCodec.BUFFER_FLAG_KEY_FRAME : 0;
            muxer.writeSampleData(trackIndices[videoTrackIndex], buffer, bufferInfo);
          }
        }

        if (session.isActive()) {
          muxer.stop();
          callback.onFinishTrim(outputFile, startMs, endMs, videoDuration);
        } else {
          callback.onCancelTrim();
        }

      } catch (IOException e) {
        e.printStackTrace();
        callback.onError("Trimming failed: " + e.getMessage(), ErrorCode.TRIMMING_FAILED);
      } finally {
        try {
          if (muxer != null && session.isActive()) {
            muxer.release();
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

