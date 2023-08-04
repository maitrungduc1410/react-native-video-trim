package com.videotrim;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

import android.app.Activity;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Build;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

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

@ReactModule(name = VideoTrimModule.NAME)
public class VideoTrimModule extends ReactContextBaseJavaModule implements VideoTrimListener, LifecycleEventListener {
  public static final String NAME = "VideoTrim";
  private static Boolean isInit = false;
  private VideoTrimmerView trimmerView;
  private AlertDialog alertDialog;
  private AlertDialog mProgressDialog;
  private ProgressBar mProgressBar;
  private Boolean mSaveToPhoto = true;
  private int mMaxDuration = 0;
  private int listenerCount = 0;

  private Promise showEditorPromise;

  public VideoTrimModule(ReactApplicationContext reactContext) {
    super(reactContext);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }


  @ReactMethod
  public void showEditor(String videoPath, ReadableMap config, Promise promise) {
    showEditorPromise = promise;
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
      buildDialog();
    });
  }

  @Override public void onTrimmingProgress(int percentage) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      mProgressBar.setProgress(percentage, true);
    } else {
      mProgressBar.setProgress(percentage);
    }
  }


  @Override public void onFinishTrim(String in) {
    runOnUiThread(() -> {
      WritableMap map = Arguments.createMap();
      map.putString("outputPath", in);
      sendEvent(getReactApplicationContext(), "onFinishTrimming", map);
      if (mSaveToPhoto) {
        showEditorPromise.resolve(in);
      } else {
        hideDialog();
      }
    });
  }

  @Override public void onError() {
    WritableMap map = Arguments.createMap();
    map.putString("message", "Error when trimming, please try again");
    sendEvent(getReactApplicationContext(), "onError", map);
    this.hideDialog();
  }

  @Override public void onCancel() {
    sendEvent(getReactApplicationContext(), "onCancelTrimming", null);
    this.hideDialog();
  }

  @ReactMethod
  private void hideDialog() {
    if (mProgressDialog != null) {
      if (mProgressDialog.isShowing()) mProgressDialog.dismiss();
      mProgressBar = null;
      mProgressDialog = null;
    }

    if (alertDialog != null) {
      if(alertDialog.isShowing()) {
        alertDialog.dismiss();
      }
      alertDialog = null;
    }
  }

  private void buildDialog() {
    Activity activity =  getReactApplicationContext().getCurrentActivity();
    // Create the parent layout for the dialog
    LinearLayout layout = new LinearLayout(activity);
    layout.setLayoutParams(new ViewGroup.LayoutParams(
      ViewGroup.LayoutParams.WRAP_CONTENT,
      ViewGroup.LayoutParams.WRAP_CONTENT
    ));
    layout.setOrientation(LinearLayout.VERTICAL);
    layout.setGravity(Gravity.CENTER_HORIZONTAL);
    layout.setPadding(16, 32, 16, 32);

    // Create and add the TextView
    TextView textView = new TextView(activity);
    textView.setLayoutParams(new ViewGroup.LayoutParams(
      ViewGroup.LayoutParams.WRAP_CONTENT,
      ViewGroup.LayoutParams.WRAP_CONTENT
    ));
    textView.setText(getReactApplicationContext().getResources().getString(R.string.trimming));
    textView.setTextSize(18);
    layout.addView(textView);

    // Create and add the ProgressBar
    mProgressBar = new ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal);
    mProgressBar.setLayoutParams(new ViewGroup.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT,
      ViewGroup.LayoutParams.WRAP_CONTENT
    ));
    mProgressBar.setProgressTintList(ColorStateList.valueOf(Color.parseColor("#2196F3")));
    layout.addView(mProgressBar);

    // Create the AlertDialog
    AlertDialog.Builder builder = new AlertDialog.Builder(activity);
    builder.setCancelable(false);
    builder.setView(layout);

    // Show the dialog
    mProgressDialog = builder.create();
    mProgressDialog.show();
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

  @ReactMethod
  private void saveVideo(String filePath, Promise promise) {
    try {
      StorageUtil.saveVideoToGallery(getReactApplicationContext(), filePath);
    } catch (IOException e) {
      e.printStackTrace();
      WritableMap mapE = Arguments.createMap();
      mapE.putString("message", "Fail while copying file to Gallery");
      sendEvent(getReactApplicationContext(), "onError", mapE);
    }

    this.hideDialog();
    promise.resolve(null);
  }
}
