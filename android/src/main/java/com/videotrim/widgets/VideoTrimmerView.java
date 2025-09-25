package com.videotrim.widgets;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;
import static com.videotrim.utils.VideoTrimmerUtil.RECYCLER_VIEW_PADDING;
import static com.videotrim.utils.VideoTrimmerUtil.VIDEO_FRAMES_WIDTH;

import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaMetadataRetriever;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.util.AttributeSet;
import android.util.Log;
import android.util.TypedValue;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.VideoView;

import androidx.appcompat.app.AlertDialog;

import com.arthenica.ffmpegkit.FFmpegSession;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableMap;
import com.videotrim.R;
import com.videotrim.enums.ErrorCode;
import com.videotrim.interfaces.IVideoTrimmerView;
import com.videotrim.interfaces.VideoTrimListener;
import com.videotrim.utils.MediaMetadataUtil;
import com.videotrim.utils.StorageUtil;
import com.videotrim.utils.VideoTrimmerUtil;

import java.io.IOException;
import java.util.Locale;
import java.util.Objects;

import iknow.android.utils.DeviceUtil;
import iknow.android.utils.thread.BackgroundExecutor;
import iknow.android.utils.thread.UiThreadExecutor;

public class VideoTrimmerView extends FrameLayout implements IVideoTrimmerView {

  private static final String TAG = VideoTrimmerView.class.getSimpleName();

  private ReactApplicationContext mContext;
  private VideoView mVideoView;

  // mediaPlayer is used for both video/audio
  // the reason we use mediaPlayer for Video: https://stackoverflow.com/a/73361868/7569705
  // the videoPlayer is to solve the issue after manually seek -> hit play -> it starts from a position slightly before with the one we just sought to
  private MediaPlayer mediaPlayer;
  private ImageView mPlayView;
  private LinearLayout mThumbnailContainer;
  private Uri mSourceUri;
  private VideoTrimListener mOnTrimVideoListener;
  private int mDuration = 0;
  private long mMaxDuration = (long) Double.POSITIVE_INFINITY;
  private long mMinDuration = VideoTrimmerUtil.MIN_SHOOT_DURATION;

  private final Handler mTimingHandler = new Handler();
  private Runnable mTimingRunnable;
  private static final long TIMING_UPDATE_INTERVAL = 30; // Update every 30 milliseconds
  private TextView currentTimeText;
  private TextView startTimeText;
  private TextView endTimeText;
  private View progressIndicator;
  private View trimmerContainer;
  // background of the trimmer container, its width never changes
  // this is to make sure when we calculate position of the progress indicator, we don't need to consider the width of the trimmer container
  private View trimmerContainerBg;
  private FrameLayout leadingHandle;
  private View trailingHandle;
  private View leadingOverlay;
  private View trailingOverlay;
  private RelativeLayout trimmerContainerWrapper;

  private long startTime = 0, endTime = 0;
  private boolean enableRotation = false;
  private double rotationAngle = 0.0;
  private long zoomOnWaitingDuration = 5000; // Default: 5 seconds (in milliseconds)

  private Vibrator vibrator;
  private boolean didClampWhilePanning = false;

  // zoom
  private boolean isZoomedIn = false;
  private final Handler zoomWaitTimer = new Handler();
  private Runnable zoomRunnable;
  private long zoomedInRangeStart = 0;
  private long zoomedInRangeDuration = 0;
  private boolean isTrimmingLeading = false;

  // thumbnail caching for zoom functionality
  private final java.util.List<ImageView> cachedFullViewThumbnails = new java.util.ArrayList<>();
  private volatile boolean isGeneratingThumbnails = false;

  private MediaMetadataRetriever mediaMetadataRetriever;
  private ProgressBar loadingIndicator;
  private TextView saveBtn;
  private TextView cancelBtn;
  private FrameLayout audioBannerView;
  private boolean isVideoType = true;
  private ImageView failToLoadBtn;

  private String mOutputExt = "mp4";
  private boolean enableHapticFeedback = true;
  private boolean autoplay = false;
  private long jumpToPositionOnLoad = 0;
  private FrameLayout headerView;
  private TextView headerText;
  private FFmpegSession ffmpegSession;
  private boolean alertOnFailToLoad = true;
  private String alertOnFailTitle = "Error";
  private String alertOnFailMessage = "Fail to load media. Possibly invalid file or no network connection";
  private String alertOnFailCloseText = "Close";
  private View currentSelectedhandle;

  private RelativeLayout trimmerView;

  private int trimmerColor = Color.parseColor(getContext().getString(R.string.trim_color)); // Default color if not set
  private int handleIconColor = Color.BLACK; // Default chevron color
  private ImageView leadingChevron;
  private ImageView trailingChevron;

  public VideoTrimmerView(ReactApplicationContext context, ReadableMap config, AttributeSet attrs) {
    this(context, attrs, 0, config);
  }

  public VideoTrimmerView(ReactApplicationContext context, AttributeSet attrs, int defStyleAttr, ReadableMap config) {
    super(context, attrs, defStyleAttr);
    init(context, config);
  }

  private void init(ReactApplicationContext context, ReadableMap config) {
    this.mContext = context;

    context.getCurrentActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
    LayoutInflater.from(context).inflate(R.layout.video_trimmer_view, this, true);
    vibrator = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);

    initializeViews();
    configure(config);
    setUpListeners();
    setProgressIndicatorTouchListener();
  }

  private void initializeViews() {
    mThumbnailContainer = findViewById(R.id.thumbnailContainer);
    mVideoView = findViewById(R.id.video_loader);
    mPlayView = findViewById(R.id.icon_video_play);
    startTimeText = findViewById(R.id.startTime);
    currentTimeText = findViewById(R.id.currentTime);
    endTimeText = findViewById(R.id.endTime);
    progressIndicator = findViewById(R.id.progressIndicator);
    trimmerContainer = findViewById(R.id.trimmerContainer);
    trimmerContainerBg = findViewById(R.id.trimmerContainerBg);
    leadingHandle = findViewById(R.id.leadingHandle);
    trailingHandle = findViewById(R.id.trailingHandle);
    leadingOverlay = findViewById(R.id.leadingOverlay);
    trailingOverlay = findViewById(R.id.trailingOverlay);

    trimmerContainerWrapper = findViewById(R.id.trimmerContainerWrapper);
    trimmerContainerWrapper.setVisibility(View.INVISIBLE);
    trimmerContainerWrapper.setAlpha(0f);

    loadingIndicator = findViewById(R.id.loadingIndicator);
    saveBtn = findViewById(R.id.saveBtn);
    cancelBtn = findViewById(R.id.cancelBtn);
    audioBannerView = findViewById(R.id.audioBannerView);
    failToLoadBtn = findViewById(R.id.failToLoadBtn);

    headerView = findViewById(R.id.headerView);
    headerText = findViewById(R.id.headerText);

    trimmerView = findViewById(R.id.trimmerView);

    leadingChevron = findViewById(R.id.leadingChevron);
    trailingChevron = findViewById(R.id.trailingChevron);
  }

  public void initByURI(final Uri videoURI) {
    mSourceUri = videoURI;

    if (isVideoType) {
      mVideoView.setVideoURI(videoURI);
      mVideoView.requestFocus();

      mVideoView.setOnPreparedListener(mp -> {
        mp.setVideoScalingMode(MediaPlayer.VIDEO_SCALING_MODE_SCALE_TO_FIT);
        mediaPlayer = mp;
        mediaPrepared();
      });

      mVideoView.setOnErrorListener(this::onFailToLoadMedia);
      mVideoView.setOnCompletionListener(mp -> mediaCompleted());
    } else {
      mVideoView.setVisibility(View.GONE);
      audioBannerView.setAlpha(0f);
      audioBannerView.setVisibility(View.VISIBLE);
      audioBannerView.animate().alpha(1f).setDuration(500).start();

      mediaPlayer = new MediaPlayer();
      try {
        mediaPlayer.setDataSource(videoURI.toString());
        mediaPlayer.setOnPreparedListener(mp -> {
          mediaPrepared();
        });
        mediaPlayer.setOnCompletionListener(mp -> mediaCompleted());
        mediaPlayer.setOnErrorListener(this::onFailToLoadMedia);

        mediaPlayer.prepareAsync(); // use prepareAsync to avoid blocking the main thread
      } catch (IOException e) {
        e.printStackTrace();
        mediaFailed();
        mOnTrimVideoListener.onError("Error initializing audio player. Please try again.", ErrorCode.FAIL_TO_INITIALIZE_AUDIO_PLAYER);
      }
    }
  }

  private boolean onFailToLoadMedia(MediaPlayer mp, int what, int extra) {
    mediaFailed();
    mOnTrimVideoListener.onError("Error loading media file. Please try again.", ErrorCode.FAIL_TO_LOAD_MEDIA);
    if (alertOnFailToLoad) {
      AlertDialog.Builder builder = new AlertDialog.Builder(mContext.getCurrentActivity());
      builder.setMessage(alertOnFailMessage);
      builder.setTitle(alertOnFailTitle);
      builder.setCancelable(false);
      builder.setPositiveButton(alertOnFailCloseText, (dialog, which) -> {
        dialog.cancel();
      });

      AlertDialog alertDialog = builder.create();
      alertDialog.show();
    }

    return true;
  }

  private void startShootVideoThumbs(final Context context, int totalThumbsCount, long startPosition, long endPosition) {
    mThumbnailContainer.removeAllViews();
    cachedFullViewThumbnails.clear(); // Clear previous cache

    VideoTrimmerUtil.shootVideoThumbInBackground(mediaMetadataRetriever, totalThumbsCount, startPosition, endPosition,
      (bitmap, interval) -> {
        if (bitmap != null) {
          runOnUiThread(() -> {
            ImageView thumbImageView = new ImageView(context);
            thumbImageView.setImageBitmap(bitmap);
            thumbImageView.setScaleType(ImageView.ScaleType.CENTER_CROP);
            LinearLayout.LayoutParams layoutParams = new LinearLayout.LayoutParams(100, LayoutParams.MATCH_PARENT);
            layoutParams.width = VideoTrimmerUtil.VIDEO_FRAMES_WIDTH / VideoTrimmerUtil.MAX_COUNT_RANGE;
            thumbImageView.setLayoutParams(layoutParams);
            mThumbnailContainer.addView(thumbImageView);

            // Cache the thumbnail for zoom functionality
            ImageView cachedView = new ImageView(context);
            cachedView.setImageBitmap(bitmap);
            cachedView.setScaleType(ImageView.ScaleType.CENTER_CROP);
            cachedView.setLayoutParams(layoutParams);
            cachedFullViewThumbnails.add(cachedView);
          });
        }
      });
  }

  private void mediaPrepared() {
    mDuration = mediaPlayer.getDuration();
    mMaxDuration = Math.min(mMaxDuration, mDuration);

    if (isVideoType) {
      mediaMetadataRetriever = MediaMetadataUtil.getMediaMetadataRetriever(mSourceUri.toString());
      if (mediaMetadataRetriever == null) {
        mOnTrimVideoListener.onError("Error when retrieving video info. Please try again.", ErrorCode.FAIL_TO_GET_VIDEO_INFO);
        return;
      }

      // take first frame
      Bitmap bitmap = mediaMetadataRetriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);

      if (bitmap != null) {
        int bitmapHeight = bitmap.getHeight() > 0 ? bitmap.getHeight() : VideoTrimmerUtil.THUMB_HEIGHT;
        int bitmapWidth = bitmap.getWidth() > 0 ? bitmap.getWidth() : VideoTrimmerUtil.THUMB_WIDTH;
        VideoTrimmerUtil.mThumbWidth = VideoTrimmerUtil.THUMB_HEIGHT * bitmapWidth / bitmapHeight;
      }

      VideoTrimmerUtil.SCREEN_WIDTH_FULL = this.getScreenWidthInPortraitMode();
      VideoTrimmerUtil.VIDEO_FRAMES_WIDTH = VideoTrimmerUtil.SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2;
      VideoTrimmerUtil.MAX_COUNT_RANGE = VideoTrimmerUtil.mThumbWidth != 0 ? Math.max((VIDEO_FRAMES_WIDTH / VideoTrimmerUtil.mThumbWidth), VideoTrimmerUtil.MAX_COUNT_RANGE) : VideoTrimmerUtil.MAX_COUNT_RANGE;

      startShootVideoThumbs(mContext, VideoTrimmerUtil.MAX_COUNT_RANGE, 0, mDuration);
    }

    // Set initial handle positions if mMaxDuration < video duration
    if (mMaxDuration < mDuration) {
      endTime = mMaxDuration;
    } else {
      endTime = mDuration;
    }
    updateHandlePositions();

    loadingIndicator.setVisibility(View.GONE);
    mPlayView.setVisibility(View.VISIBLE);
    saveBtn.setVisibility(View.VISIBLE);

    if (jumpToPositionOnLoad > 0) {
      seekTo(jumpToPositionOnLoad > mDuration ? mDuration : jumpToPositionOnLoad, true);
    }

    if (autoplay) {
      playOrPause();
    }

    mOnTrimVideoListener.onLoad(mDuration);
    ignoreSystemGestureForView(trimmerView);
  }

  private void updateGradientColors(int startColor, int endColor) {
    GradientDrawable gradientDrawable = new GradientDrawable();
    gradientDrawable.setShape(GradientDrawable.RECTANGLE);
    gradientDrawable.setCornerRadius(6f); // Adjust corner radius as needed
    gradientDrawable.setColors(new int[]{startColor, endColor});
    gradientDrawable.setOrientation(GradientDrawable.Orientation.LEFT_RIGHT);

    mThumbnailContainer.setBackground(gradientDrawable);
  }

  private void mediaFailed() {
    loadingIndicator.setVisibility(View.GONE);
    failToLoadBtn.setVisibility(View.VISIBLE);
  }

  private void updateHandlePositions() {
    // Use zoom-aware position calculation
    float leadingHandleX = positionForTime(startTime);
    float trailingHandleX = positionForTime(endTime);

    leadingHandle.setX(leadingHandleX);
    trailingHandle.setX(trailingHandleX + trailingHandle.getWidth());

    updateTrimmerContainerWidth();
    updateCurrentTime(false);

    trimmerContainerWrapper.setVisibility(View.VISIBLE);
    trimmerContainerWrapper.animate().alpha(1f).setDuration(250).start();
  }

  private void mediaCompleted() {
    onMediaPause();

    // when mediaCompleted is called,  the endTime may not be exactly at the end of the video (can be slightly before), therefore we should seek to exact position on ended
    seekTo(endTime, true);
  }

  private void playOrPause() {
    if (mediaPlayer.isPlaying()) {
      onMediaPause();
    } else {
      if (mediaPlayer.getCurrentPosition() >= endTime) {
        seekTo(startTime, true);
      }
      mediaPlayer.start();
      startTimingRunnable();
    }
    setPlayPauseViewIcon(mediaPlayer.isPlaying());
  }

  public void onMediaPause() {
    mTimingHandler.removeCallbacks(mTimingRunnable);
    if (mediaPlayer.isPlaying()) {
      mediaPlayer.pause();
    }
    setPlayPauseViewIcon(false);
  }

  public void setOnTrimVideoListener(VideoTrimListener onTrimVideoListener) {
    mOnTrimVideoListener = onTrimVideoListener;
  }

  private void setUpListeners() {
    cancelBtn.setOnClickListener(view -> mOnTrimVideoListener.onCancel());
    saveBtn.setOnClickListener(view -> mOnTrimVideoListener.onSave());
    mPlayView.setOnClickListener(view -> playOrPause());
    setHandleTouchListener(leadingHandle, true);
    setHandleTouchListener(trailingHandle, false);
  }

  public void onSaveClicked() {
    onMediaPause();
    ffmpegSession = VideoTrimmerUtil.trim(
      mSourceUri.toString(),
      StorageUtil.getOutputPath(mContext, mOutputExt),
      mDuration,
      startTime,
      endTime,
      enableRotation,
      rotationAngle,
      mOnTrimVideoListener
    );
  }

  public void onCancelTrimClicked() {
    if (ffmpegSession != null) {
      ffmpegSession.cancel();
    } else {
      mOnTrimVideoListener.onCancelTrim();
    }
  }

  private void seekTo(long msec, boolean needUpdateProgress) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      mediaPlayer.seekTo((int) msec, MediaPlayer.SEEK_CLOSEST);
    } else {
      mediaPlayer.seekTo((int) msec);
    }

    updateCurrentTime(needUpdateProgress);
  }

  private void setPlayPauseViewIcon(boolean isPlaying) {
    // note: icons imported from SF symbols have 0.85 opacity we should change to 1 here
    mPlayView.setImageResource(isPlaying ? R.drawable.pause_fill : R.drawable.play_fill);
  }

  @Override
  protected void onDetachedFromWindow() {
    super.onDetachedFromWindow();
    mContext.getCurrentActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);
  }

  @Override
  public void onDestroy() {
    // Stop any ongoing operations
    isGeneratingThumbnails = false;
    BackgroundExecutor.cancelAll("", true);
    UiThreadExecutor.cancelAll("");
    mContext.getCurrentActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);
    mTimingHandler.removeCallbacks(mTimingRunnable);
    zoomWaitTimer.removeCallbacks(zoomRunnable);

    // Clear cached thumbnails to prevent memory leaks
    cachedFullViewThumbnails.clear();

    try {
      if (mediaMetadataRetriever != null) {
        mediaMetadataRetriever.release();
      }
    } catch (Exception e) {
      e.printStackTrace();
    }

    try {
      if (mediaPlayer != null) {
        mediaPlayer.stop();
        mediaPlayer.release();
      }
    } catch (IllegalStateException e) {
      // if it's video, resource is released with the view, and here we also call .release which will throw exception
      e.printStackTrace();
      Log.d(TAG, "onDestroy mediaPlayer is already released");
    }
  }

  private int getScreenWidthInPortraitMode() {
    int screenWidth = DeviceUtil.getDeviceWidth();
    int screenHeight = DeviceUtil.getDeviceHeight();
    int currentOrientation = getResources().getConfiguration().orientation;
    if (currentOrientation == Configuration.ORIENTATION_LANDSCAPE) {
      return screenHeight;
    }
    return screenWidth;
  }

  private void configure(ReadableMap config) {
    if (config.hasKey("maxDuration") && config.getDouble("maxDuration") > 0) {
      mMaxDuration = (long) Math.max(0, config.getDouble("maxDuration") * 1000L);
    }

    if (config.hasKey("minDuration") && config.getDouble("minDuration") > 0) {
      mMinDuration = (long) Math.max(1000L, config.getDouble("minDuration") * 1000L);
    }

    cancelBtn.setText(config.getString("cancelButtonText"));
    saveBtn.setText(config.getString("saveButtonText"));
    isVideoType = config.hasKey("type") && Objects.equals(config.getString("type"), "video");
    System.out.println("isVideoType: " + isVideoType);

    mOutputExt = config.hasKey("outputExt") ? config.getString("outputExt") : "mp4";
    if (!isVideoType) {
      mOutputExt = "wav";
    }
    enableHapticFeedback = config.hasKey("enableHapticFeedback") && config.getBoolean("enableHapticFeedback");
    autoplay = config.hasKey("autoplay") && config.getBoolean("autoplay");

    if (config.hasKey("jumpToPositionOnLoad") && config.getDouble("jumpToPositionOnLoad") > 0) {
      jumpToPositionOnLoad = (long) Math.max(0, config.getDouble("jumpToPositionOnLoad") * 1000L);
    }
    headerText.setText(config.hasKey("headerText") ? config.getString("headerText") : "");

    int textSize = config.hasKey("headerTextSize") ? config.getInt("headerTextSize") : 16;
    if (textSize < 0) {
      textSize = 16;
    }

    headerText.setTextSize(TypedValue.COMPLEX_UNIT_DIP, textSize);
    headerText.setTextColor(config.hasKey("headerTextColor") ? config.getInt("headerTextColor") : Color.BLACK);

    headerView.setVisibility(View.VISIBLE);
    alertOnFailToLoad = config.hasKey("alertOnFailToLoad") && config.getBoolean("alertOnFailToLoad");
    alertOnFailTitle = config.hasKey("alertOnFailTitle") ? config.getString("alertOnFailTitle") : "Error";
    alertOnFailMessage = config.hasKey("alertOnFailMessage") ? config.getString("alertOnFailMessage") : "Fail to load media. Possibly invalid file or no network connection";
    alertOnFailCloseText = config.hasKey("alertOnFailCloseText") ? config.getString("alertOnFailCloseText") : "Close";
    enableRotation = config.hasKey("enableRotation") && config.getBoolean("enableRotation");
    rotationAngle = config.hasKey("rotationAngle") ? config.getDouble("rotationAngle") : 0.0;
    
    // Configure zoom on waiting duration (in seconds, converted to milliseconds)
    if (config.hasKey("zoomOnWaitingDuration") && config.getDouble("zoomOnWaitingDuration") > 0) {
      zoomOnWaitingDuration = (long) (config.getDouble("zoomOnWaitingDuration"));
      Log.d(TAG, "Configured zoom on waiting duration: " + (zoomOnWaitingDuration / 1000.0) + " seconds");
    }

    trimmerColor = config.hasKey("trimmerColor") ? config.getInt("trimmerColor") : Color.parseColor(getContext().getString(R.string.trim_color));
    handleIconColor = config.hasKey("handleIconColor") ? config.getInt("handleIconColor") : Color.BLACK;

    applyTrimmerColor();
  }

  private void applyTrimmerColor() {
    // Trimmer border (stroke only)
    GradientDrawable borderDrawable = new GradientDrawable();
    borderDrawable.setShape(GradientDrawable.RECTANGLE);
    borderDrawable.setColor(Color.TRANSPARENT);
    borderDrawable.setStroke(dpToPx(4), trimmerColor);
    trimmerContainer.setBackground(borderDrawable);

    // Leading handle (rounded left corners)
    GradientDrawable leadingHandleDrawable = new GradientDrawable();
    leadingHandleDrawable.setShape(GradientDrawable.RECTANGLE);
    leadingHandleDrawable.setColor(trimmerColor);
    leadingHandleDrawable.setCornerRadii(new float[]{dpToPx(6), dpToPx(6), 0, 0, 0, 0, dpToPx(6), dpToPx(6)});
    leadingHandle.setBackground(leadingHandleDrawable);

    // Trailing handle (rounded right corners)
    GradientDrawable trailingHandleDrawable = new GradientDrawable();
    trailingHandleDrawable.setShape(GradientDrawable.RECTANGLE);
    trailingHandleDrawable.setColor(trimmerColor);
    trailingHandleDrawable.setCornerRadii(new float[]{0, 0, dpToPx(6), dpToPx(6), dpToPx(6), dpToPx(6), 0, 0});
    trailingHandle.setBackground(trailingHandleDrawable);

    // Chevron colors
    leadingChevron.setColorFilter(handleIconColor, android.graphics.PorterDuff.Mode.SRC_IN);
    trailingChevron.setColorFilter(handleIconColor, android.graphics.PorterDuff.Mode.SRC_IN);
  }

  private int dpToPx(int dp) {
    return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, getResources().getDisplayMetrics());
  }

  private void startTimingRunnable() {
    mTimingRunnable = new Runnable() {
      @Override
      public void run() {
        try {
          int currentPosition = mediaPlayer.getCurrentPosition();

          if (currentPosition >= endTime) {
            onMediaPause();
            seekTo(endTime, true); // Ensure exact end time display
          } else {
            updateCurrentTime(true);
            mTimingHandler.postDelayed(this, TIMING_UPDATE_INTERVAL);
          }
        } catch (IllegalStateException e) {
          e.printStackTrace();
          mTimingHandler.removeCallbacks(mTimingRunnable);
          // this is to catch the error thrown if we close editor while playing (mediaPlayer is released)
        }
      }
    };
    mTimingHandler.postDelayed(mTimingRunnable, TIMING_UPDATE_INTERVAL);
  }

  private void updateCurrentTime(boolean needUpdateProgress) {
    int currentPosition = mediaPlayer.getCurrentPosition();
    int duration = mDuration;

    if (currentPosition >= duration - 100) {
      currentPosition = duration;
    } else if (currentPosition >= endTime - 100) {
      currentPosition = (int) endTime;
    } else if (currentPosition <= startTime + 100) {
      currentPosition = (int) startTime;
    }

    String currentTime = formatTime(currentPosition);
    currentTimeText.setText(currentTime);

    String startTime = formatTime((int) this.startTime);
    startTimeText.setText(startTime);

    String endTime = formatTime((int) this.endTime);
    endTimeText.setText(endTime);

    if (needUpdateProgress) {
      // Update progressIndicator position using zoom-aware calculation
      float indicatorPosition;

      if (isZoomedIn) {
        // Calculate position relative to zoomed range
        long visibleRangeStart = getVisibleRangeStart();
        long visibleRangeDuration = getVisibleRangeDuration();

        // Ensure current position is within visible range for proper calculation
        if (currentPosition < visibleRangeStart || currentPosition > visibleRangeStart + visibleRangeDuration) {
          // If current position is outside visible range, clamp it
          currentPosition = (int) Math.max(visibleRangeStart, Math.min(visibleRangeStart + visibleRangeDuration, currentPosition));
        }

        float ratio = visibleRangeDuration > 0 ? (float) (currentPosition - visibleRangeStart) / visibleRangeDuration : 0;
        indicatorPosition = ratio * (trimmerContainerBg.getWidth() - progressIndicator.getWidth()) + leadingHandle.getWidth();
      } else {
        // Calculate position relative to full duration (original logic)
        indicatorPosition = mDuration > 0 ? (float) currentPosition / mDuration * (trimmerContainerBg.getWidth() - progressIndicator.getWidth()) + leadingHandle.getWidth() : leadingHandle.getWidth();
      }

      // Ensure indicator stays within handle bounds using actual handle positions
      float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
      float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();

      // Apply bounds checking based on actual handle positions
      indicatorPosition = Math.max(leftBoundary, Math.min(rightBoundary, indicatorPosition));

      if (currentSelectedhandle == leadingHandle) {
        progressIndicator.setX(Math.max(leftBoundary, indicatorPosition));
      } else if (currentSelectedhandle == trailingHandle) {
        progressIndicator.setX(Math.min(rightBoundary, indicatorPosition));
      } else {
        // Normal playback - use calculated position with handle bounds
        progressIndicator.setX(indicatorPosition);
      }
    }
  }

  private String formatTime(int milliseconds) {
    int totalSeconds = milliseconds / 1000;
    int minutes = totalSeconds / 60;
    int seconds = totalSeconds % 60;
    int millis = milliseconds % 1000;
    return String.format(Locale.getDefault(), "%d:%02d.%03d", minutes, seconds, millis);
  }

  private void setProgressIndicatorTouchListener() {
    trimmerContainerBg.setOnTouchListener((view, event) -> {
      switch (event.getAction()) {
        case MotionEvent.ACTION_DOWN:
          didClampWhilePanning = false;
          onMediaPause();
          onTrimmerContainerPanned(event);
          playHapticFeedback(true);
          break;
        case MotionEvent.ACTION_MOVE:
          onTrimmerContainerPanned(event);
          break;
        case MotionEvent.ACTION_UP:
          view.performClick();
          break;
        default:
          return false;
      }
      return true;
    });
  }

  private void onTrimmerContainerPanned(MotionEvent event) {
    float newX = event.getRawX();
    boolean didClamp = false;

    // Use handle positions for boundaries instead of trimmer container
    float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
    float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();

    newX = Math.max(leftBoundary, newX);
    newX = Math.min(rightBoundary, newX);

    // check play haptic feedback
    if (newX <= leftBoundary) {
      didClamp = true;
    } else if (newX >= rightBoundary) {
      didClamp = true;
    }

    if (didClamp && !didClampWhilePanning) {
      playHapticFeedback(false);
    }
    didClampWhilePanning = didClamp;

    progressIndicator.setX(newX);

    float indicatorPosition = newX - (trimmerContainerBg.getX());

    // Calculate video position based on zoom state
    float indicatorPositionPercent;
    long newVideoPosition;

    if (isZoomedIn) {
      // Calculate relative to zoomed range
      indicatorPositionPercent = indicatorPosition / (trimmerContainerBg.getWidth() - progressIndicator.getWidth());
      long visibleStart = getVisibleRangeStart();
      long visibleDuration = getVisibleRangeDuration();
      newVideoPosition = visibleStart + (long) (indicatorPositionPercent * visibleDuration);
    } else {
      // Calculate relative to full duration
      indicatorPositionPercent = indicatorPosition / (trimmerContainerBg.getWidth() - progressIndicator.getWidth());
      newVideoPosition = (long) (indicatorPositionPercent * mDuration);
    }

    seekTo(newVideoPosition, false);
  }

  private void setHandleTouchListener(View handle, boolean isLeading) {
    handle.setOnTouchListener((view, event) -> {
      boolean draggingDisabled = mDuration < mMinDuration; // if the video is shorter than the minimum duration, disable dragging
      switch (event.getAction()) {
        case MotionEvent.ACTION_DOWN:
          currentSelectedhandle = handle;
          didClampWhilePanning = false;
          onMediaPause();
          fadeOutProgressIndicator();
          seekTo(isLeading ? startTime : endTime, true);
          playHapticFeedback(true);
          isTrimmingLeading = isLeading;
          break;
        case MotionEvent.ACTION_MOVE:
          if (draggingDisabled) {
            return false;
          }

          boolean didClamp = false;
          float newX = event.getRawX() - ((float) view.getWidth() / 2);

          // Handle constraints need to consider zoom state
          if (isLeading) {
            newX = Math.max(0, Math.min(newX, trailingHandle.getX() - view.getWidth()));
          } else {
            newX = Math.min(trimmerContainerBg.getWidth() + view.getWidth(), Math.max(newX, leadingHandle.getX() + view.getWidth()));
          }

          view.setX(newX);

          // Calculate new startTime or endTime based on zoom state
          if (isLeading) {
            // Calculate the new startTime based on the handle's new position
            long newStartTime = timeForPosition(newX);
            // Calculate the duration between the new startTime and the current endTime
            long duration = endTime - newStartTime;
            if (duration >= mMinDuration && duration <= mMaxDuration) {
              // If the duration is within the allowed range, update startTime and move the progress indicator
              startTime = newStartTime;
              float indicatorX = newX + view.getWidth();
              // Ensure progress indicator stays within handle bounds
              float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
              float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
              progressIndicator.setX(Math.max(leftBoundary, Math.min(rightBoundary, indicatorX)));
            } else if (duration < mMinDuration) {
              didClamp = true;
              // If the duration is less than the minimum, calculate maximum startTime to maintain minimum duration
              startTime = endTime - mMinDuration;

              // In zoom mode, don't recalculate position - keep handle where it is but update times
              if (isZoomedIn) {
                // Keep handle at current position but clamp times
                float indicatorX = newX + view.getWidth();
                float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
                float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
                progressIndicator.setX(Math.max(leftBoundary, Math.min(rightBoundary, indicatorX)));
              } else {
                // Normal mode - adjust handle position
                view.setX(positionForTime(startTime));
                float indicatorX = view.getX() + view.getWidth();
                float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
                float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
                progressIndicator.setX(Math.max(leftBoundary, Math.min(rightBoundary, indicatorX)));
              }
            } else {
              didClamp = true;
              // If the duration is greater than the maximum, calculate minimum startTime to maintain maximum duration
              startTime = endTime - mMaxDuration;

              // In zoom mode, don't recalculate position - keep handle where it is but update times
              if (isZoomedIn) {
                // Keep handle at current position but clamp times
                float indicatorX = newX + view.getWidth();
                float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
                float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
                progressIndicator.setX(Math.max(leftBoundary, Math.min(rightBoundary, indicatorX)));
              } else {
                // Normal mode - adjust handle position
                view.setX(positionForTime(startTime));
                float indicatorX = view.getX() + view.getWidth();
                float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
                float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
                progressIndicator.setX(Math.max(leftBoundary, Math.min(rightBoundary, indicatorX)));
              }
            }
          } else {
            // Calculate the new endTime based on the handle's new position
            long newEndTime = timeForPosition(newX - view.getWidth());
            // Calculate the duration between the new endTime and the current startTime
            long duration = newEndTime - startTime;
            if (duration >= mMinDuration && duration <= mMaxDuration) {
              // If the duration is within the allowed range, update endTime and move the progress indicator
              endTime = newEndTime;
              float indicatorX = newX - progressIndicator.getWidth();
              // Ensure progress indicator stays within handle bounds
              float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
              float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
              progressIndicator.setX(Math.max(leftBoundary, Math.min(rightBoundary, indicatorX)));
            } else if (duration < mMinDuration) {
              didClamp = true;
              // If the duration is less than the minimum, calculate minimum endTime to maintain minimum duration
              endTime = startTime + mMinDuration;

              // In zoom mode, don't recalculate position - keep handle where it is but update times
              if (isZoomedIn) {
                // Keep handle at current position but clamp times
                float indicatorX = newX - progressIndicator.getWidth();
                float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
                float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
                progressIndicator.setX(Math.max(leftBoundary, Math.min(rightBoundary, indicatorX)));
              } else {
                // Normal mode - adjust handle position
                view.setX(positionForTime(endTime) + view.getWidth());
                float indicatorX = view.getX() - progressIndicator.getWidth();
                float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
                float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
                progressIndicator.setX(Math.max(leftBoundary, Math.min(rightBoundary, indicatorX)));
              }
            } else {
              didClamp = true;
              // If the duration is greater than the maximum, calculate maximum endTime to maintain maximum duration
              endTime = startTime + mMaxDuration;

              // In zoom mode, don't recalculate position - keep handle where it is but update times
              if (isZoomedIn) {
                // Keep handle at current position but clamp times
                float indicatorX = newX - progressIndicator.getWidth();
                float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
                float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
                progressIndicator.setX(Math.max(leftBoundary, Math.min(rightBoundary, indicatorX)));
              } else {
                // Normal mode - adjust handle position
                view.setX(positionForTime(endTime) + view.getWidth());
                float indicatorX = view.getX() - progressIndicator.getWidth();
                float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
                float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
                progressIndicator.setX(Math.max(leftBoundary, Math.min(rightBoundary, indicatorX)));
              }
            }
          }

          if (didClamp && !didClampWhilePanning) {
            playHapticFeedback(false);
          }
          didClampWhilePanning = didClamp;

          updateTrimmerContainerWidth();
          seekTo(isLeading ? startTime : endTime, false);

          // Start zoom wait timer when dragging handles
          startZoomWaitTimer();
          break;
        case MotionEvent.ACTION_UP:
          stopZoomIfNeeded();
          fadeInProgressIndicator();
          view.performClick();
          break;
        default:
          return false;
      }
      return true;
    });
  }

  private void fadeOutProgressIndicator() {
    progressIndicator.animate().alpha(0f).setDuration(250).withEndAction(() -> progressIndicator.setVisibility(View.INVISIBLE)).start();
  }

  private void fadeInProgressIndicator() {
    progressIndicator.setVisibility(View.VISIBLE);
    progressIndicator.animate().alpha(1f).setDuration(250).start();
  }

  private void updateTrimmerContainerWidth() {
    int left = (int) leadingHandle.getX() + leadingHandle.getWidth();
    int right = trimmerContainerBg.getWidth() - (int) trailingHandle.getX() + 2 * trailingHandle.getWidth();

    RelativeLayout.LayoutParams leadingOverlayParams = (RelativeLayout.LayoutParams) leadingOverlay.getLayoutParams();
    leadingOverlayParams.width = left;
    leadingOverlayParams.height = RelativeLayout.LayoutParams.MATCH_PARENT;
    leadingOverlayParams.addRule(RelativeLayout.ALIGN_PARENT_START);
    leadingOverlay.setLayoutParams(leadingOverlayParams);

    RelativeLayout.LayoutParams trailingOverlayParams = (RelativeLayout.LayoutParams) trailingOverlay.getLayoutParams();
    trailingOverlayParams.width = right;
    trailingOverlayParams.height = RelativeLayout.LayoutParams.MATCH_PARENT;
    trailingOverlayParams.addRule(RelativeLayout.ALIGN_PARENT_END);
    trailingOverlay.setLayoutParams(trailingOverlayParams);
  }

  private void playHapticFeedback(boolean isLight) {
    if (vibrator != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && enableHapticFeedback) {
      vibrator.vibrate(VibrationEffect.createOneShot(isLight ? 10 : 25, VibrationEffect.DEFAULT_AMPLITUDE)); // Light vibration
    }
  }

  private void startZoomWaitTimer() {
    stopZoomWaitTimer();
    if (isZoomedIn) {
      return;
    }

    zoomRunnable = () -> {
      stopZoomWaitTimer();
      zoomIfNeeded();
    };

    zoomWaitTimer.postDelayed(zoomRunnable, 500);
  }

  private void stopZoomWaitTimer() {
    if (zoomRunnable != null) {
      zoomWaitTimer.removeCallbacks(zoomRunnable);
    }
  }

  private void stopZoomIfNeeded() {
    stopZoomWaitTimer();
    if (isZoomedIn) {
      // Stop any ongoing thumbnail generation immediately
      isGeneratingThumbnails = false;

      // Cancel any ongoing background tasks for thumbnail generation
      BackgroundExecutor.cancelAll("progressive_thumbs", true);

      isZoomedIn = false;

      // Immediately restore cached thumbnails without waiting for animation
      restoreCachedThumbnails();

      // Then apply smooth transition animation
      animateZoomTransition(() -> {
        updateHandlePositions();
        // Force update progress indicator position after exiting zoom
        updateCurrentTime(true);
      });
    }
  }

  private void zoomIfNeeded() {
    if (isZoomedIn) {
      return;
    }

    // Store current handle positions to maintain visual continuity
    float currentLeadingX = leadingHandle.getX();
    float currentTrailingX = trailingHandle.getX();

    // Use configurable zoom duration, but ensure it's reasonable for the video
    long newDuration = Math.min(zoomOnWaitingDuration, mDuration);
    
    // For very short videos, use a smaller zoom range
    if (mDuration < 2000) {
      newDuration = Math.max(500, mDuration / 2); // At least 0.5 seconds for very short videos
    } else if (mDuration < zoomOnWaitingDuration) {
      newDuration = Math.max(1000, mDuration / 2); // Use half duration for short videos
    }

    // Ensure zoom duration doesn't exceed video duration
    newDuration = Math.min(newDuration, mDuration);

    long rangeStart;
    if (isTrimmingLeading) {
      // Zoom around the start time, but ensure we don't go before video start
      rangeStart = Math.max(0, startTime - (newDuration / 2));
      // If range would extend past video end, adjust start
      if (rangeStart + newDuration > mDuration) {
        rangeStart = Math.max(0, mDuration - newDuration);
      }
    } else {
      // Zoom around the end time
      rangeStart = Math.max(0, endTime - (newDuration / 2));
      // If range would extend past video end, adjust start
      if (rangeStart + newDuration > mDuration) {
        rangeStart = Math.max(0, mDuration - newDuration);
      }
    }

    // Final bounds check
    zoomedInRangeStart = Math.max(0, rangeStart);
    zoomedInRangeDuration = Math.min(newDuration, mDuration - zoomedInRangeStart);

    isZoomedIn = true;

    // Start progressive thumbnail generation immediately
    startProgressiveThumbnailGeneration();

    // Update handle positions immediately without delay
    updateHandlePositionsForZoom(currentLeadingX, currentTrailingX);

    // Provide haptic feedback
    playHapticFeedback(true);
  }

  private void updateHandlePositionsForZoom(float previousLeadingX, float previousTrailingX) {
    // During zoom, we want to keep handles at their current visual positions
    // Don't recalculate based on zoom range - this causes jumping

    Log.d(TAG, "Maintaining handle positions during zoom - Leading: " + previousLeadingX + ", Trailing: " + previousTrailingX);

    // Keep handles exactly where they were visually
    leadingHandle.setX(previousLeadingX);
    trailingHandle.setX(previousTrailingX);

    // Don't update times here - let the individual handle drag logic handle that
    // This prevents unwanted changes to startTime/endTime during zoom transition

    // Update trimmer container width based on current handle positions
    updateTrimmerContainerWidth();

    // Ensure progress indicator is positioned correctly within the handle bounds
    float leftBoundary = leadingHandle.getX() + leadingHandle.getWidth();
    float rightBoundary = trailingHandle.getX() - progressIndicator.getWidth();
    float currentX = progressIndicator.getX();

    // If progress indicator is out of bounds, position it properly
    if (currentX < leftBoundary || currentX > rightBoundary) {
      // Position it based on the current media position
      updateCurrentTime(true);
    } else {
      updateCurrentTime(false);
    }

    trimmerContainerWrapper.setVisibility(View.VISIBLE);
    if (trimmerContainerWrapper.getAlpha() == 0f) {
      trimmerContainerWrapper.animate().alpha(1f).setDuration(250).start();
    }
  }

  private void startProgressiveThumbnailGeneration() {
    if (isGeneratingThumbnails || mediaMetadataRetriever == null) {
      return;
    }

    isGeneratingThumbnails = true;

    // Immediately create placeholder thumbnails with subtle animation
    UiThreadExecutor.runTask("", () -> {
      mThumbnailContainer.removeAllViews();

      // Calculate proper number of thumbnails based on container width
      final int thumbnailWidth = VideoTrimmerUtil.VIDEO_FRAMES_WIDTH / VideoTrimmerUtil.MAX_COUNT_RANGE;
      final int numberOfThumbnails = Math.max(8, mThumbnailContainer.getWidth() / thumbnailWidth);

      // Create placeholder thumbnails first
      for (int i = 0; i < numberOfThumbnails; i++) {
        ImageView placeholder = new ImageView(getContext());
        LinearLayout.LayoutParams layoutParams = new LinearLayout.LayoutParams(thumbnailWidth, LinearLayout.LayoutParams.MATCH_PARENT);
        placeholder.setLayoutParams(layoutParams);
        placeholder.setBackgroundColor(Color.parseColor("#F0F0F0")); // Light gray placeholder
        placeholder.setAlpha(0.2f);
        mThumbnailContainer.addView(placeholder);
      }
    }, 0);

    // Start background thumbnail generation
    BackgroundExecutor.execute(new BackgroundExecutor.Task("progressive_thumbs", 0L, "") {
      @Override
      public void execute() {
        try {
          final int thumbnailWidth = VideoTrimmerUtil.VIDEO_FRAMES_WIDTH / VideoTrimmerUtil.MAX_COUNT_RANGE;
          final int numberOfThumbnails = Math.max(8, mThumbnailContainer.getWidth() / thumbnailWidth);
          final long visibleDuration = isZoomedIn ? zoomedInRangeDuration : mDuration;
          final long visibleStart = isZoomedIn ? zoomedInRangeStart : 0;
          final long interval = visibleDuration > 0 ? visibleDuration / numberOfThumbnails : 0;

          // Generate thumbnails progressively
          for (int i = 0; i < numberOfThumbnails && isGeneratingThumbnails && isZoomedIn; i++) {
            // Check if we should continue generating
            if (!isGeneratingThumbnails || !isZoomedIn) {
              Log.d(TAG, "Thumbnail generation cancelled at index " + i);
              return;
            }

            final int index = i;
            final long timeUs = (visibleStart + (i * interval)) * 1000; // Convert to microseconds
            final long clampedTimeUs = Math.max(0, Math.min(timeUs, mDuration * 1000L));

            try {
              Bitmap bitmap = mediaMetadataRetriever.getFrameAtTime(clampedTimeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
              if (bitmap != null && isGeneratingThumbnails && isZoomedIn) {
                // Update UI immediately for each thumbnail
                UiThreadExecutor.runTask("", () -> {
                  // Double-check zoom state before updating UI
                  if (isZoomedIn && index < mThumbnailContainer.getChildCount()) {
                    ImageView thumbnailView = (ImageView) mThumbnailContainer.getChildAt(index);
                    if (thumbnailView != null) {
                      thumbnailView.setImageBitmap(bitmap);
                      thumbnailView.setScaleType(ImageView.ScaleType.CENTER_CROP);
                      thumbnailView.setBackground(null); // Remove placeholder background

                      // Smooth fade-in animation for each thumbnail
                      thumbnailView.animate()
                          .alpha(1.0f)
                          .setDuration(150)
                          .setStartDelay(index * 50L) // Stagger animations
                          .start();
                    }
                  }
                }, 0);

                // Small delay between generations to avoid blocking
                Thread.sleep(10);
              }
            } catch (Exception e) {
              Log.w(TAG, "Error generating progressive thumbnail at " + clampedTimeUs, e);
            }
          }

          // Only finalize if we're still in zoom mode
          if (isGeneratingThumbnails && isZoomedIn) {
            isGeneratingThumbnails = false;
          } else {
            isGeneratingThumbnails = false;
          }

        } catch (Exception e) {
          Log.e(TAG, "Error in progressive thumbnail generation", e);
          isGeneratingThumbnails = false;
        }
      }
    });
  }

  private void animateZoomTransition(Runnable onComplete) {
    // Only animate if we're still transitioning
    if (mThumbnailContainer != null) {
      mThumbnailContainer.animate()
          .alpha(0.7f)
          .setDuration(200) // Shorter duration for better responsiveness
          .withEndAction(() -> {
            if (onComplete != null) {
              onComplete.run();
            }
            if (mThumbnailContainer != null) {
              mThumbnailContainer.animate()
                  .alpha(1.0f)
                  .setDuration(200)
                  .start();
            }
          })
          .start();
    } else if (onComplete != null) {
      onComplete.run();
    }
  }

  private void ignoreSystemGestureForView(View v) {
    // Android 10+
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      // 1. setSystemGestureExclusionRects on a rect which is entire screen size
      // 2. if we use the bound of the view, it's not smooth and still sometimes can trigger system gesture even our finger is within the view bound
      // 3. even though here the bound is set to screen size, it doesn't mean the entire screen is excluded from system gesture, it only means the area within the view bound is excluded
      v.setSystemGestureExclusionRects(
        java.util.List.of(
          new android.graphics.Rect(
            0,
            0,
            DeviceUtil.getDeviceWidth(),
            DeviceUtil.getDeviceHeight()
          )
        )
      );
    }
  }

  // Helper methods for position/time conversion considering zoom state
  private long timeForPosition(float position) {
    if (trimmerContainerBg.getWidth() <= 0) return 0;

    if (isZoomedIn) {
      // Convert position to time within zoomed range
      float ratio = position / trimmerContainerBg.getWidth();
      return zoomedInRangeStart + (long) (ratio * zoomedInRangeDuration);
    } else {
      // Convert position to time within full duration
      return (long) ((position / trimmerContainerBg.getWidth()) * mDuration);
    }
  }

  private float positionForTime(long time) {
    if (isZoomedIn) {
      // Convert time to position within zoomed range
      if (zoomedInRangeDuration <= 0) return 0;
      float ratio = (float) (time - zoomedInRangeStart) / zoomedInRangeDuration;
      return Math.max(0, Math.min(trimmerContainerBg.getWidth(), ratio * trimmerContainerBg.getWidth()));
    } else {
      // Convert time to position within full duration
      if (mDuration <= 0) return 0;
      return Math.max(0, Math.min(trimmerContainerBg.getWidth(), ((float) time / mDuration) * trimmerContainerBg.getWidth()));
    }
  }

  private long getVisibleRangeStart() {
    return isZoomedIn ? zoomedInRangeStart : 0;
  }

  private long getVisibleRangeDuration() {
    return isZoomedIn ? zoomedInRangeDuration : mDuration;
  }

  private void restoreCachedThumbnails() {
    // Clear current thumbnails
    mThumbnailContainer.removeAllViews();

    // Restore cached thumbnails efficiently
    for (ImageView cachedThumbnail : cachedFullViewThumbnails) {
      // Create a new ImageView with the same bitmap to avoid view reuse issues
      ImageView restoredView = new ImageView(getContext());
      restoredView.setImageBitmap(((android.graphics.drawable.BitmapDrawable) cachedThumbnail.getDrawable()).getBitmap());
      restoredView.setScaleType(ImageView.ScaleType.CENTER_CROP);
      restoredView.setLayoutParams(cachedThumbnail.getLayoutParams());
      mThumbnailContainer.addView(restoredView);
    }
  }
}
