package com.videotrim;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;
import android.app.Activity;
import android.app.ProgressDialog;
import android.media.MediaMetadataRetriever;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.videotrim.interfaces.VideoTrimListener;
import com.videotrim.utils.StorageUtil;
import com.videotrim.widgets.VideoTrimmerView;
import java.io.IOException;
import iknow.android.utils.BaseUtils;
import nl.bravobit.ffmpeg.FFmpeg;

@ReactModule(name = VideoTrimModule.NAME)
public class VideoTrimModule extends ReactContextBaseJavaModule implements VideoTrimListener, LifecycleEventListener {
  public static final String NAME = "VideoTrim";
  private static Boolean isInit = false;
  private VideoTrimmerView trimmerView;
  private AlertDialog alertDialog;
  private ProgressDialog mProgressDialog;
  private Boolean mSaveToPhoto = true;
  private int mMaxDuration = 0;
  private int listenerCount = 0;

  public VideoTrimModule(ReactApplicationContext reactContext) {
    super(reactContext);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }


  @ReactMethod
  public void showEditor(String videoPath, ReadableMap config) {
    if (trimmerView != null || alertDialog != null) {
      return;
    }

    if (config.hasKey("saveToPhoto")) {
      this.mSaveToPhoto = config.getBoolean("saveToPhoto");
    }
    if (config.hasKey("maxDuration")) {
      this.mMaxDuration = config.getInt("maxDuration");
    }

    if (!_isValidVideo(videoPath)) {
      WritableMap map = Arguments.createMap();
      map.putString("message", "File is not a valid video");
      sendEvent(getReactApplicationContext(), "onError", map);
      return;
    }

    Activity activity = getReactApplicationContext().getCurrentActivity();

    if (!isInit) {
      init(activity);
      isInit = true;
    }

    // here is NOT main thread, we need to create VideoTrimmerView on UI thread, so that later we can update it using same thread

    runOnUiThread(() -> {
      trimmerView = new VideoTrimmerView(getReactApplicationContext(), mMaxDuration, null);
      trimmerView.setOnTrimVideoListener(this);
      trimmerView.initVideoByURI(Uri.parse(videoPath));

      AlertDialog.Builder builder = new AlertDialog.Builder(activity, android.R.style.Theme_Black_NoTitleBar_Fullscreen);
      builder.setCancelable(false);
      alertDialog = builder.create();
      alertDialog.setView(trimmerView);
      alertDialog.show();

      // this is to ensure to release resource if dialog is dismissed in unexpected way (Eg. open control/notification center by dragging from top of screen)
      alertDialog.setOnDismissListener(dialog -> {
        // This is called in same thread as the trimmer view -> UI thread
        if (trimmerView != null) {
          trimmerView.onDestroy();
          trimmerView = null;
        }
        hideDialog();
        sendEvent(getReactApplicationContext(), "onHide", null);
      });
      sendEvent(getReactApplicationContext(), "onShow", null);
    });
  }

  private void init(Activity activity) {
    isInit = true;
    // we have to init this before create videoTrimmerView
    BaseUtils.init(getReactApplicationContext());
    if (!FFmpeg.getInstance(getReactApplicationContext()).isSupported()) {
      // we have to call this for FFMPEG to initialize, otherwise it'll throw can't open ffmpeg (no such file or dir)
      WritableMap mapE = Arguments.createMap();
      mapE.putString("message", "Android CPU arch not supported");
      sendEvent(getReactApplicationContext(), "onError", mapE);
    }
  }

  @Override
  public void onHostResume() {

  }

  @Override
  public void onHostPause() {
    if (trimmerView != null) {
      trimmerView.onVideoPause();
      trimmerView.setRestoreState(true);
    }
  }

  @Override
  public void onHostDestroy() {
    hideDialog();
  }

  @Override public void onStartTrim() {
    sendEvent(getReactApplicationContext(), "onStartTrimming", null);
    runOnUiThread(() -> {
      buildDialog(getReactApplicationContext().getResources().getString(R.string.trimming)).show();
    });
  }

  @Override public void onFinishTrim(String in) {
    if (mProgressDialog.isShowing()) mProgressDialog.dismiss();
    WritableMap map = Arguments.createMap();
    map.putString("outputPath", in);
    sendEvent(getReactApplicationContext(), "onFinishTrimming", map);
    if (mSaveToPhoto) {
      try {
        StorageUtil.saveVideoToGallery(getReactApplicationContext(), in);
      } catch (IOException e) {
        e.printStackTrace();
        WritableMap mapE = Arguments.createMap();
        mapE.putString("message", "Fail to save to Gallery. Please check if you have correct permission");
        sendEvent(getReactApplicationContext(), "onError", mapE);
      }
    }
    this.hideDialog();
  }

  @Override public void onCancel() {
    sendEvent(getReactApplicationContext(), "onCancelTrimming", null);
    this.hideDialog();
  }

  private void hideDialog() {
    if (alertDialog != null) {
      if(alertDialog.isShowing()) {
        alertDialog.dismiss();
      }
      alertDialog = null;
    }
  }

  private ProgressDialog buildDialog(String msg) {
    if (mProgressDialog == null) {
      mProgressDialog = ProgressDialog.show(getReactApplicationContext().getCurrentActivity(), "", msg);
    }
    mProgressDialog.setMessage(msg);
    return mProgressDialog;
  }

  @ReactMethod
  public void addListener(String eventName) {
    // This method is required by React
    listenerCount += 1;
  }

  @ReactMethod
  public void removeListeners(Integer count) {
    // This method is required by React
    listenerCount -= count;
  }

  private void sendEvent(ReactContext reactContext, String eventName, @Nullable WritableMap params) {
    if (listenerCount > 0) {
      WritableMap map = params != null ? params : Arguments.createMap();
      map.putString("name", eventName);
      reactContext
        .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
        .emit("VideoTrim", map);
    }
  }

  public boolean _isValidVideo(String filePath) {
    MediaMetadataRetriever retriever = new MediaMetadataRetriever();

    try {
      retriever.setDataSource(getReactApplicationContext(), Uri.parse(filePath));
    } catch (Exception e){
      e.printStackTrace();
      return false;
    }

    String hasVideo = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO);
    return "yes".equals(hasVideo);
  }

  @ReactMethod
  private void isValidVideo(String filePath, Promise promise) {
    promise.resolve(_isValidVideo(filePath));
  }
}
