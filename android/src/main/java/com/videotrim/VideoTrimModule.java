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
  private int listenerCount = 0;

  private Promise showEditorPromise;

  private boolean enableCancelDialog = true;
  private String cancelDialogTitle = "Warning!";
  private String cancelDialogMessage = "Are you sure want to cancel?";
  private String cancelDialogCancelText = "Close";
  private String cancelDialogConfirmText = "Proceed";
  private boolean enableSaveDialog = true;
  private String saveDialogTitle = "Confirmation!";
  private String saveDialogMessage = "Are you sure want to save?";
  private String saveDialogCancelText = "Close";
  private String saveDialogConfirmText  = "Proceed";
  private String trimmingText = "Trimming video...";

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

    if (!isValidVideo(videoPath)) {
      WritableMap map = Arguments.createMap();
      map.putString("message", "File is not a valid video");
      sendEvent(getReactApplicationContext(), "onError", map);
      return;
    }

    enableCancelDialog = config.hasKey("enableCancelDialog") ? config.getBoolean("enableCancelDialog") : true;
    cancelDialogTitle = config.hasKey("cancelDialogTitle") ? config.getString("cancelDialogTitle") : "Warning!";
    cancelDialogMessage = config.hasKey("cancelDialogMessage") ? config.getString("cancelDialogMessage") : "Are you sure want to cancel?";
    cancelDialogCancelText = config.hasKey("cancelDialogCancelText") ? config.getString("cancelDialogCancelText") : "Close";
    cancelDialogConfirmText = config.hasKey("cancelDialogConfirmText") ? config.getString("cancelDialogConfirmText") : "Proceed";

    enableSaveDialog = config.hasKey("enableSaveDialog") ? config.getBoolean("enableSaveDialog") : true;
    saveDialogTitle = config.hasKey("saveDialogTitle") ? config.getString("saveDialogTitle") : "Confirmation!";
    saveDialogMessage = config.hasKey("saveDialogMessage") ? config.getString("saveDialogMessage") : "Are you sure want to save?";
    saveDialogCancelText = config.hasKey("saveDialogCancelText") ? config.getString("saveDialogCancelText") : "Close";
    saveDialogConfirmText = config.hasKey("saveDialogConfirmText") ? config.getString("saveDialogConfirmText") : "Proceed";
    trimmingText = config.hasKey("trimmingText") ? config.getString("trimmingText") : "Trimming video...";

    Activity activity = getReactApplicationContext().getCurrentActivity();

    if (!isInit) {
      init(activity);
      isInit = true;
    }

    // here is NOT main thread, we need to create VideoTrimmerView on UI thread, so that later we can update it using same thread

    runOnUiThread(() -> {
      trimmerView = new VideoTrimmerView(getReactApplicationContext(), config, null);
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
      showEditorPromise.resolve(in);
    });
  }

  @Override public void onError(String errorMessage) {
    WritableMap map = Arguments.createMap();
    map.putString("message", errorMessage);
    sendEvent(getReactApplicationContext(), "onError", map);
    this.hideDialog();
  }

  @Override public void onCancel() {
    if (!enableCancelDialog) {
      sendEvent(getReactApplicationContext(), "onCancelTrimming", null);
      hideDialog();
      return;
    }

    AlertDialog.Builder builder = new AlertDialog.Builder(getReactApplicationContext().getCurrentActivity());
    builder.setMessage(cancelDialogMessage);
    builder.setTitle(cancelDialogTitle);
    builder.setCancelable(false);
    builder.setPositiveButton(cancelDialogConfirmText, (dialog, which) -> {
      dialog.cancel();
      sendEvent(getReactApplicationContext(), "onCancelTrimming", null);
      hideDialog();
    });
    builder.setNegativeButton(cancelDialogCancelText, (dialog, which) -> {
      dialog.cancel();
    });
    AlertDialog alertDialog = builder.create();
    alertDialog.show();
  }

  @Override public void onSave() {
    if (!enableSaveDialog) {
      trimmerView.onSaveClicked();
      return;
    }

    AlertDialog.Builder builder = new AlertDialog.Builder(getReactApplicationContext().getCurrentActivity());
    builder.setMessage(saveDialogMessage);
    builder.setTitle(saveDialogTitle);
    builder.setCancelable(false);
    builder.setPositiveButton(saveDialogConfirmText, (dialog, which) -> {
      dialog.cancel();
      trimmerView.onSaveClicked();
    });
    builder.setNegativeButton(saveDialogCancelText, (dialog, which) -> {
      dialog.cancel();
    });
    AlertDialog alertDialog = builder.create();
    alertDialog.show();
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
    Activity activity = getReactApplicationContext().getCurrentActivity();
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
    textView.setText(trimmingText);
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


  public boolean isValidVideo(String filePath) {
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
    promise.resolve(isValidVideo(filePath));
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

  @ReactMethod
  private void listFiles(Promise promise) {
    String[] files = StorageUtil.listFiles(getReactApplicationContext());
    promise.resolve(Arguments.fromArray(files));
  }

  @ReactMethod
  private void cleanFiles(Promise promise) {
    String[] files = StorageUtil.listFiles(getReactApplicationContext());
    int successCount = 0;
    for (String file : files) {
      boolean state = StorageUtil.deleteFile(file);
      if (state) {
        successCount++;
      }
    }
    promise.resolve(successCount);
  }

  @ReactMethod
  private void deleteFile(String filePath, Promise promise) {
    boolean state = StorageUtil.deleteFile(filePath);
    promise.resolve(state);
  }
}
