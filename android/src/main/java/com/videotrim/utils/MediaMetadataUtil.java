package com.videotrim.utils;

import android.media.MediaMetadataRetriever;
import android.os.Build;
import android.util.Log;

import java.io.IOException;
import java.util.HashMap;

public class MediaMetadataUtil {

  private static final String TAG = "MediaMetadataUtil";

  // Function to return MediaMetadataRetriever or null
  public static MediaMetadataRetriever getMediaMetadataRetriever(String source) {
    MediaMetadataRetriever retriever = new MediaMetadataRetriever();
    try {
      Log.d(TAG, "Attempting to set data source: " + source + " on device: " + Build.MANUFACTURER + " " + Build.MODEL + " (Android " + Build.VERSION.RELEASE + ")");
      
      if (source.startsWith("http://") || source.startsWith("https://")) {
        retriever.setDataSource(source, new HashMap<>());
      } else {
        retriever.setDataSource(source);
      }
      
      Log.d(TAG, "Successfully set data source for: " + source);
      return retriever;
    } catch (Exception e) {
      Log.e(TAG, "Error setting data source for: " + source + " on device: " + Build.MANUFACTURER + " " + Build.MODEL + " (Android " + Build.VERSION.RELEASE + ")", e);
      Log.e(TAG, "Exception type: " + e.getClass().getSimpleName() + ", Message: " + e.getMessage());
      
      try {
        retriever.release();
      } catch (Exception ee) {
        Log.e(TAG, "Error releasing retriever", ee);
      }
      
      // For Samsung devices, try an alternative approach
      if (Build.MANUFACTURER.equalsIgnoreCase("samsung")) {
        Log.d(TAG, "Samsung device detected, attempting alternative metadata retrieval approach");
        return getMediaMetadataRetrieverForSamsung(source);
      }
      
      return null;
    }
  }

  // Samsung-specific alternative approach for MediaMetadataRetriever
  private static MediaMetadataRetriever getMediaMetadataRetrieverForSamsung(String source) {
    Log.d(TAG, "Attempting Samsung-specific metadata retrieval for: " + source);
    
    MediaMetadataRetriever retriever = new MediaMetadataRetriever();
    try {
      // For Samsung devices, try with a slight delay and different approach
      try {
        Thread.sleep(100); // Small delay to handle Samsung timing issues
      } catch (InterruptedException ie) {
        Thread.currentThread().interrupt(); // Restore interrupted status
        Log.w(TAG, "Samsung retry delay interrupted", ie);
      }
      
      if (source.startsWith("http://") || source.startsWith("https://")) {
        // For remote files, use default approach
        retriever.setDataSource(source, new HashMap<>());
      } else {
        // For local files, ensure proper URI format for Samsung devices
        String processedSource = source;
        if (source.startsWith("content://") || source.startsWith("file://")) {
          processedSource = source;
        } else if (!source.startsWith("/")) {
          // Ensure absolute path
          processedSource = "/" + source;
        }
        
        Log.d(TAG, "Samsung device: Using processed source: " + processedSource);
        retriever.setDataSource(processedSource);
      }
      
      // Test if the retriever actually works by trying to get duration
      String duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
      Log.d(TAG, "Samsung device: Successfully retrieved metadata, duration: " + duration);
      
      return retriever;
    } catch (Exception e) {
      Log.e(TAG, "Samsung-specific metadata retrieval also failed for: " + source, e);
      try {
        retriever.release();
      } catch (Exception ee) {
        Log.e(TAG, "Error releasing Samsung retriever", ee);
      }
      return null;
    }
  }

  public static void checkFileValidity(String urlString, FileValidityCallback callback) {
    new Thread(() -> {
      boolean isValid = false;
      String fileType = "unknown";
      long duration;
      MediaMetadataRetriever retriever = getMediaMetadataRetriever(urlString);
      if (retriever == null) {
        callback.onResult(false, fileType, -1L);
        return;
      }

      // Retrieve the duration
      String durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
      duration = durationStr == null ? -1L : Long.parseLong(durationStr);

      // Determine the type
      String hasVideo = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO);
      if (hasVideo != null && hasVideo.equals("yes")) {
        fileType = "video";
        isValid = true;
      } else {
        String hasAudio = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO);
        if (hasAudio != null && hasAudio.equals("yes")) {
          fileType = "audio";
          isValid = true;
        }
      }

      try {
        retriever.release();
      } catch (IOException e) {
        Log.e(TAG, "Error releasing retriever", e);
      }
      callback.onResult(isValid, fileType, isValid ? duration : -1L);
    }).start();
  }

  public interface FileValidityCallback {
    void onResult(boolean isValid, String fileType, Long duration);
  }
}

