package com.videotrim.utils;

import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.util.Log;

import java.io.File;
import java.io.IOException;
import java.util.HashMap;

public class MediaMetadataUtil {

  private static final String TAG = "MediaMetadataUtil";

  // Function to return MediaMetadataRetriever or null
  public static MediaMetadataRetriever getMediaMetadataRetriever(String source) {
    MediaMetadataRetriever retriever = new MediaMetadataRetriever();
    try {
      if (source.startsWith("http://") || source.startsWith("https://")) {
        retriever.setDataSource(source, new HashMap<>());
      } else {
        String filePath = source;

        // if "source" is not a valid file path, try to parse it as a URI
        if (!StorageUtil.isFileExists(filePath)) {
          Log.e(TAG, "File does not exist, trying to parse as URI: " + source);

          Uri uri = Uri.parse(source);
          filePath = uri.getPath();

          if (!StorageUtil.isFileExists(filePath)) {
            Log.e(TAG, "File does not exist at path: " + filePath);
            return null;
          }
        }

        retriever.setDataSource(filePath);
      }
      return retriever;
    } catch (Exception e) {
      Log.e(TAG, "Error setting data source", e);
      try {
        retriever.release();
      } catch (Exception ee) {
        Log.e(TAG, "Error releasing retriever", ee);
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

