package com.videotrim.widgets;

import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;
import static com.videotrim.utils.VideoTrimmerUtil.RECYCLER_VIEW_PADDING;
import static com.videotrim.utils.VideoTrimmerUtil.VIDEO_FRAMES_WIDTH;

import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.util.AttributeSet;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.VideoView;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableMap;
import com.videotrim.R;
import com.videotrim.interfaces.IVideoTrimmerView;
import com.videotrim.interfaces.VideoTrimListener;
import com.videotrim.utils.StorageUtil;
import com.videotrim.utils.VideoTrimmerUtil;

import java.util.Locale;

import iknow.android.utils.DeviceUtil;
import iknow.android.utils.thread.BackgroundExecutor;
import iknow.android.utils.thread.UiThreadExecutor;

public class VideoTrimmerView extends FrameLayout implements IVideoTrimmerView {

  private static final String TAG = VideoTrimmerView.class.getSimpleName();

  private ReactApplicationContext mContext;
  private VideoView mVideoView;
  private ImageView mPlayView;
  private LinearLayout mThumbnailContainer;
  private Uri mSourceUri;
  private VideoTrimListener mOnTrimVideoListener;
  private int mDuration = 0;
  private Boolean mIsPrepared = false;
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
  private Vibrator vibrator;
  private boolean didClampWhilePanning = false;

  // zoom
  private boolean isZoomedIn = false;
  private final Handler zoomWaitTimer = new Handler();
  private Runnable zoomRunnable;

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
  }

  public void initVideoByURI(final Uri videoURI) {
    mSourceUri = videoURI;
    mVideoView.setVideoURI(videoURI);
    mVideoView.requestFocus();
  }

  private void startShootVideoThumbs(final Context context, final Uri videoUri, int totalThumbsCount, long startPosition, long endPosition) {
    mThumbnailContainer.removeAllViews();
    VideoTrimmerUtil.shootVideoThumbInBackground(context, videoUri, totalThumbsCount, startPosition, endPosition,
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
          });
        }
      });
  }

  private void videoPrepared(MediaPlayer mp) {
    mDuration = mVideoView.getDuration();

    mMaxDuration = Math.min(mMaxDuration, mDuration);

    MediaMetadataRetriever mediaMetadataRetriever = new MediaMetadataRetriever();
    mediaMetadataRetriever.setDataSource(mContext, mSourceUri);
    // take first frame
    Bitmap bitmap = mediaMetadataRetriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);

    if (bitmap != null) {
      VideoTrimmerUtil.mThumbWidth = VideoTrimmerUtil.THUMB_HEIGHT * bitmap.getWidth() / bitmap.getHeight();
    }

    VideoTrimmerUtil.SCREEN_WIDTH_FULL = this.getScreenWidthInPortraitMode();
    VideoTrimmerUtil.VIDEO_FRAMES_WIDTH = VideoTrimmerUtil.SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2;
    VideoTrimmerUtil.MAX_COUNT_RANGE = Math.max((VIDEO_FRAMES_WIDTH / VideoTrimmerUtil.mThumbWidth), VideoTrimmerUtil.MAX_COUNT_RANGE);

    int mThumbsTotalCount;
    mThumbsTotalCount = (int) (mDuration * 1.0f / (mMaxDuration * 1.0f) * VideoTrimmerUtil.MAX_COUNT_RANGE);
    startShootVideoThumbs(mContext, mSourceUri, mThumbsTotalCount, 0, mDuration);

    // Set initial handle positions if mMaxDuration < video duration
    if (mMaxDuration < mDuration) {
      endTime = mMaxDuration;
    } else {
      endTime = mDuration;
    }
    updateHandlePositions();
  }

  private void updateHandlePositions() {
    float startPercent = (float) startTime / mVideoView.getDuration();
    float endPercent = (float) endTime / mVideoView.getDuration();

    float containerWidth = trimmerContainerBg.getWidth();
    float leadingHandleX = startPercent * containerWidth;
    float trailingHandleX = endPercent * containerWidth;

    leadingHandle.setX(leadingHandleX);
    trailingHandle.setX(trailingHandleX + trailingHandle.getWidth());

    updateTrimmerContainerWidth();
    updateCurrentTime(false);

    trimmerContainerWrapper.setVisibility(View.VISIBLE);
    trimmerContainerWrapper.animate().alpha(1f).setDuration(250).start();

    // because on load video will not start and just display black screen
    // here we'll seek to first frame to make it more friendly
    mVideoView.seekTo(1);
  }

  private void videoCompleted() {
    setPlayPauseViewIcon(false);
    mTimingHandler.removeCallbacks(mTimingRunnable);
  }

  private void playOrPause() {
    if (mVideoView.isPlaying()) {
      onVideoPause();
    } else {
      // if current video time >= end time, seek to start time
      if (mVideoView.getCurrentPosition() >= endTime) {
        seekTo(startTime, true);
      }
      mVideoView.start();
      startTimingRunnable();
    }
    setPlayPauseViewIcon(mVideoView.isPlaying());
  }

  public void onVideoPause() {
    if (mVideoView.isPlaying()) {
      mTimingHandler.removeCallbacks(mTimingRunnable);
      mVideoView.pause();
      setPlayPauseViewIcon(false);
    }
  }

  public void setOnTrimVideoListener(VideoTrimListener onTrimVideoListener) {
    mOnTrimVideoListener = onTrimVideoListener;
  }

  private void setUpListeners() {
    findViewById(R.id.cancelBtn).setOnClickListener(view -> mOnTrimVideoListener.onCancel());
    findViewById(R.id.saveBtn).setOnClickListener(view -> mOnTrimVideoListener.onSave());

    mVideoView.setOnPreparedListener(mp -> {
      if (!mIsPrepared) {
        mp.setVideoScalingMode(MediaPlayer.VIDEO_SCALING_MODE_SCALE_TO_FIT);
        videoPrepared(mp);
        mIsPrepared = true;
      }
    });

    mVideoView.setOnCompletionListener(mp -> videoCompleted());
    mPlayView.setOnClickListener(view -> playOrPause());
    setHandleTouchListener(leadingHandle, true);
    setHandleTouchListener(trailingHandle, false);
  }

  public void onSaveClicked() {
    onVideoPause();
    VideoTrimmerUtil.trim(
      mSourceUri.getPath(),
      StorageUtil.getOutputPath(mContext),
      mDuration,
      startTime,
      endTime,
      mOnTrimVideoListener);
  }

  private void seekTo(long msec, boolean needUpdateProgress) {
    mVideoView.seekTo((int) msec);
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
    BackgroundExecutor.cancelAll("", true);
    UiThreadExecutor.cancelAll("");
    mContext.getCurrentActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);
    mTimingHandler.removeCallbacks(mTimingRunnable);
    zoomWaitTimer.removeCallbacks(zoomRunnable);
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
    if (config.hasKey("maxDuration")) {
      mMaxDuration = Math.max(0, config.getInt("maxDuration") * 1000L);
    }
    if (config.hasKey("minDuration")) {
      mMinDuration = Math.max(1000L, config.getInt("minDuration") * 1000L);
    }
    if (config.hasKey("cancelButtonText")) {
      TextView tv = findViewById(R.id.cancelBtn);
      tv.setText(config.getString("cancelButtonText"));
    }
    if (config.hasKey("saveButtonText")) {
      TextView tv = findViewById(R.id.saveBtn);
      tv.setText(config.getString("saveButtonText"));
    }
  }

  private void startTimingRunnable() {
    mTimingRunnable = new Runnable() {
      @Override
      public void run() {
        int currentPosition = mVideoView.getCurrentPosition();

        if (currentPosition >= endTime) {
          onVideoPause();
          seekTo(endTime, true); // Ensure exact end time display
        } else {
          updateCurrentTime(true);
          mTimingHandler.postDelayed(this, TIMING_UPDATE_INTERVAL);
        }
      }
    };
    mTimingHandler.postDelayed(mTimingRunnable, TIMING_UPDATE_INTERVAL);
  }

  private void updateCurrentTime(boolean needUpdateProgress) {
    // TODO: check the case after drag the progress indicator and hit play, it'll play a little bit earlier than the progress indicator
    int currentPosition = mVideoView.getCurrentPosition();
    int duration = mVideoView.getDuration();

    if (currentPosition >= duration - 100) {
      currentPosition = duration;
    } else if (currentPosition >= endTime - 100) {
      currentPosition = (int) endTime;
    }

    String currentTime = formatTime(currentPosition);
    currentTimeText.setText(currentTime);

    String startTime = formatTime((int) this.startTime);
    startTimeText.setText(startTime);

    String endTime = formatTime((int) this.endTime);
    endTimeText.setText(endTime);

    if (needUpdateProgress) {
      // Update progressIndicator position
      float indicatorPosition = (float) currentPosition / duration * (trimmerContainerBg.getWidth() - progressIndicator.getWidth()) + leadingHandle.getWidth();

      float rightBoundary = trimmerContainer.getX() + trimmerContainer.getWidth() - progressIndicator.getWidth();

      progressIndicator.setX(Math.min(rightBoundary, indicatorPosition));
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
          onVideoPause();
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
    // Ensure newX is within valid range
    float leftBoundary = trimmerContainer.getX();
    float rightBoundary = trimmerContainer.getX() + trimmerContainer.getWidth() - progressIndicator.getWidth();
    newX = Math.max(leftBoundary, newX);
    newX = Math.min(rightBoundary, newX);

    // check play haptic feedback
    if (newX <= leftBoundary) {
      didClamp = true;
    }
    else if (newX >= rightBoundary) {
      didClamp = true;
    }

    if (didClamp && !didClampWhilePanning) {
      playHapticFeedback(false);
    }
    didClampWhilePanning = didClamp;

    progressIndicator.setX(newX);

    float indicatorPosition = newX - (trimmerContainerBg.getX());

    // TODO: check this
    float indicatorPositionPercent = indicatorPosition / (trimmerContainerBg.getWidth() - progressIndicator.getWidth());
    long newVideoPosition = (long) (indicatorPositionPercent * mVideoView.getDuration());

    seekTo(newVideoPosition, false);
  }
  private void setHandleTouchListener(View handle, boolean isLeading) {
    handle.setOnTouchListener((view, event) -> {
      switch (event.getAction()) {
        case MotionEvent.ACTION_DOWN:
          didClampWhilePanning = false;
          onVideoPause();
          fadeOutProgressIndicator();
          seekTo(isLeading ? startTime : endTime, true);
          playHapticFeedback(true);
          break;
        case MotionEvent.ACTION_MOVE:
          boolean didClamp = false;
          float newX = event.getRawX() - ((float) view.getWidth() / 2);
          if (isLeading) {
            newX = Math.max(0, Math.min(newX, trailingHandle.getX() - view.getWidth()));
          } else {
            newX = Math.min(trimmerContainerBg.getWidth() + view.getWidth(), Math.max(newX, leadingHandle.getX() + view.getWidth()));
          }

          view.setX(newX);

          // Calculate new startTime or endTime
          if (isLeading) {
            // Calculate the new startTime based on the handle's new position
            long newStartTime = (long) ((newX / trimmerContainerBg.getWidth()) * mVideoView.getDuration());
            // Calculate the duration between the new startTime and the current endTime
            long duration = endTime - newStartTime;
            if (duration >= mMinDuration && duration <= mMaxDuration) {
              // If the duration is within the allowed range, update startTime and move the progress indicator
              startTime = newStartTime;
              progressIndicator.setX(newX + view.getWidth());
            } else if (duration < mMinDuration) {
              didClamp = true;
              // If the duration is less than the minimum, set startTime to the maximum possible to maintain the minimum duration
              startTime = endTime - mMinDuration;
              // Adjust the handle position accordingly
              view.setX((float) startTime / mVideoView.getDuration() * trimmerContainerBg.getWidth());
              progressIndicator.setX(view.getX() + view.getWidth());
            } else {
              didClamp = true;
              // If the duration is greater than the maximum, set startTime to the minimum possible to maintain the maximum duration
              startTime = endTime - mMaxDuration;
              // Adjust the handle position accordingly
              view.setX((float) startTime / mVideoView.getDuration() * trimmerContainerBg.getWidth());
              progressIndicator.setX(view.getX() + view.getWidth());
            }
          } else {
            // Calculate the new endTime based on the handle's new position
            long newEndTime = (long) (((newX - view.getWidth()) / trimmerContainerBg.getWidth()) * mVideoView.getDuration());
            // Calculate the duration between the new endTime and the current startTime
            long duration = newEndTime - startTime;
            if (duration >= mMinDuration && duration <= mMaxDuration) {
              // If the duration is within the allowed range, update endTime and move the progress indicator
              endTime = newEndTime;
              progressIndicator.setX(newX - progressIndicator.getWidth());
            } else if (duration < mMinDuration) {
              didClamp = true;
              // If the duration is less than the minimum, set endTime to the minimum possible to maintain the minimum duration
              endTime = startTime + mMinDuration;
              // Adjust the handle position accordingly
              view.setX((float) endTime / mVideoView.getDuration() * trimmerContainerBg.getWidth() + view.getWidth());
              progressIndicator.setX(view.getX() - progressIndicator.getWidth());
            } else {
              didClamp = true;
              // If the duration is greater than the maximum, set endTime to the maximum possible to maintain the maximum duration
              endTime = startTime + mMaxDuration;
              // Adjust the handle position accordingly
              view.setX((float) endTime / mVideoView.getDuration() * trimmerContainerBg.getWidth() + view.getWidth());
              progressIndicator.setX(view.getX() - progressIndicator.getWidth());
            }
          }

          if (didClamp && !didClampWhilePanning) {
            playHapticFeedback(false);
          }
          didClampWhilePanning = didClamp;

          updateTrimmerContainerWidth();
          seekTo(isLeading ? startTime : endTime, false);

          // TODO: create zoom feature like iOS
//          startZoomWaitTimer();
          break;
        case MotionEvent.ACTION_UP:
//          stopZoomIfNeeded();
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
    if (vibrator != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      vibrator.vibrate(VibrationEffect.createOneShot(isLight ? 10 : 25, VibrationEffect.DEFAULT_AMPLITUDE)); // Light vibration
    }
  }

  private void startZoomWaitTimer() {
    stopZoomWaitTimer();
    if (isZoomedIn) {
      return;
    }

    zoomRunnable = () -> {
      Log.i("tag","A Kiss after 500ms");
      stopZoomWaitTimer();
      zoomIfNeeded();
    };

    zoomWaitTimer.postDelayed(zoomRunnable, 500);
  }

  private void stopZoomWaitTimer() {
    zoomWaitTimer.removeCallbacks(zoomRunnable);
  }

  private void stopZoomIfNeeded() {
    stopZoomWaitTimer();
    isZoomedIn = false;
  }

  private void zoomIfNeeded() {
    if (isZoomedIn) {
      return;
    }

    startShootVideoThumbs(mContext, mSourceUri, 10, 5000, 10000);

    isZoomedIn = true;
  }
}
