package com.videotrim.widgets;

import static com.videotrim.utils.VideoTrimmerUtil.RECYCLER_VIEW_PADDING;
import static com.videotrim.utils.VideoTrimmerUtil.VIDEO_FRAMES_WIDTH;

import android.animation.ValueAnimator;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Handler;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.LinearInterpolator;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableMap;
import com.videotrim.R;
import com.videotrim.adapters.VideoTrimmerAdapter;
import com.videotrim.interfaces.IVideoTrimmerView;
import com.videotrim.interfaces.VideoTrimListener;
import com.videotrim.utils.StorageUtil;
import com.videotrim.utils.VideoTrimmerUtil;

import iknow.android.utils.DeviceUtil;
import iknow.android.utils.thread.BackgroundExecutor;
import iknow.android.utils.thread.UiThreadExecutor;

/**
 * Author：J.Chou
 * Date：  2016.08.01 2:23 PM
 * Email： who_know_me@163.com
 * Describe:
 */
public class VideoTrimmerView extends FrameLayout implements IVideoTrimmerView {

  private static final String TAG = VideoTrimmerView.class.getSimpleName();

  private int mMaxWidth = VIDEO_FRAMES_WIDTH;
  private ReactApplicationContext mContext;
  private RelativeLayout mLinearVideo;
  private ZVideoView mVideoView;
  private ImageView mPlayView;
  private RecyclerView mVideoThumbRecyclerView;
  private RangeSeekBarView mRangeSeekBarView;
  private LinearLayout mSeekBarLayout;
  private ImageView mRedProgressIcon;
  private float mAverageMsPx;//每毫秒所占的px
  private float averagePxMs;//每px所占用的ms毫秒
  private Uri mSourceUri;
  private VideoTrimListener mOnTrimVideoListener;
  private int mDuration = 0;
  private VideoTrimmerAdapter mVideoThumbAdapter;
  private boolean isFromRestore = false;
  //new
  private long mLeftProgressPos, mRightProgressPos;
  private long mRedProgressBarPos = 0;
  private long scrollPos = 0;
  private int mScaledTouchSlop;
  private int lastScrollX;
  private boolean isSeeking;
  private boolean isOverScaledTouchSlop;
  private int mThumbsTotalCount;
  private ValueAnimator mRedProgressAnimator;
  private Handler mAnimationHandler = new Handler();
  private Boolean mIsPrepared = false;
  private int mMaxDuration = 0;


  public VideoTrimmerView(ReactApplicationContext context, AttributeSet attrs) {
    this(context, attrs, 0, null);
  }
  public VideoTrimmerView(ReactApplicationContext context, ReadableMap config, AttributeSet attrs) {
    this(context, attrs, 0, config);
  }

  public VideoTrimmerView(ReactApplicationContext context, AttributeSet attrs, int defStyleAttr, ReadableMap config) {
    super(context, attrs, defStyleAttr);
    init(context, config);
  }

  private void init(ReactApplicationContext context, ReadableMap config) {
    this.mContext = context;

    // listen to onConfigurationChanged doesn't work for this, it runs too soon
    context.getCurrentActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
    LayoutInflater.from(context).inflate(R.layout.video_trimmer_view, this, true);

    mLinearVideo = findViewById(R.id.layout_surface_view);
    mVideoView = findViewById(R.id.video_loader);
    mPlayView = findViewById(R.id.icon_video_play);
    mSeekBarLayout = findViewById(R.id.seekBarLayout);
    mRedProgressIcon = findViewById(R.id.positionIcon);
    mVideoThumbRecyclerView = findViewById(R.id.video_frames_recyclerView);
    mVideoThumbRecyclerView.setLayoutManager(new LinearLayoutManager(mContext, LinearLayoutManager.HORIZONTAL, false));
    mVideoThumbAdapter = new VideoTrimmerAdapter(mContext);
    mVideoThumbRecyclerView.setAdapter(mVideoThumbAdapter);
    mVideoThumbRecyclerView.addOnScrollListener(mOnScrollListener);

    configure(config);
    setUpListeners();
  }

  private void initRangeSeekBarView() {
    if(mRangeSeekBarView != null) return;
    mLeftProgressPos = 0;

    VideoTrimmerUtil.SCREEN_WIDTH_FULL = this.getScreenWidthInPortraitMode();
    VideoTrimmerUtil.VIDEO_FRAMES_WIDTH = VideoTrimmerUtil.SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2;
    VideoTrimmerUtil.MAX_COUNT_RANGE = Math.max(((int) VIDEO_FRAMES_WIDTH / VideoTrimmerUtil.mThumbWidth),  VideoTrimmerUtil.MAX_COUNT_RANGE);

    if (mDuration <= VideoTrimmerUtil.maxShootDuration) {
      mThumbsTotalCount = VideoTrimmerUtil.MAX_COUNT_RANGE;
      mRightProgressPos = mDuration;
    } else {
      mThumbsTotalCount = (int) (mDuration * 1.0f / (VideoTrimmerUtil.maxShootDuration * 1.0f) * VideoTrimmerUtil.MAX_COUNT_RANGE);
      mRightProgressPos = VideoTrimmerUtil.maxShootDuration;
    }

    mVideoThumbRecyclerView.addItemDecoration(new SpacesItemDecoration2(RECYCLER_VIEW_PADDING, mThumbsTotalCount));
    mRangeSeekBarView = new RangeSeekBarView(mContext, mLeftProgressPos, mRightProgressPos);
    mRangeSeekBarView.setSelectedMinValue(mLeftProgressPos);
    mRangeSeekBarView.setSelectedMaxValue(mRightProgressPos);
    mRangeSeekBarView.setStartEndTime(mLeftProgressPos, mRightProgressPos);
    mRangeSeekBarView.setMinShootTime(VideoTrimmerUtil.MIN_SHOOT_DURATION);
    mRangeSeekBarView.setNotifyWhileDragging(true);
    mRangeSeekBarView.setOnRangeSeekBarChangeListener(mOnRangeSeekBarChangeListener);
    mSeekBarLayout.addView(mRangeSeekBarView);
    if(mThumbsTotalCount - VideoTrimmerUtil.MAX_COUNT_RANGE > 0) {
      mAverageMsPx = (mDuration - VideoTrimmerUtil.maxShootDuration) / (float) (mThumbsTotalCount - VideoTrimmerUtil.MAX_COUNT_RANGE);
    } else {
      mAverageMsPx = 0f;
    }
    averagePxMs = (mMaxWidth * 1.0f / (mRightProgressPos - mLeftProgressPos));
  }

  public void initVideoByURI(final Uri videoURI) {
    mSourceUri = videoURI;
    mVideoView.setVideoURI(videoURI);
    mVideoView.requestFocus();
  }

  private void startShootVideoThumbs(final Context context, final Uri videoUri, int totalThumbsCount, long startPosition, long endPosition) {
    VideoTrimmerUtil.shootVideoThumbInBackground(context, videoUri, totalThumbsCount, startPosition, endPosition,
      (bitmap, interval) -> {
        if (bitmap != null) {
          UiThreadExecutor.runTask("", () -> mVideoThumbAdapter.addBitmaps(bitmap), 0L);
        }
      });
  }

  private void videoPrepared(MediaPlayer mp) {
    ViewGroup.LayoutParams lp = mVideoView.getLayoutParams();
    int videoWidth = mp.getVideoWidth();
    int videoHeight = mp.getVideoHeight();

    float videoProportion = (float) videoWidth / (float) videoHeight;
    int screenWidth = mLinearVideo.getWidth();
    int screenHeight = mLinearVideo.getHeight();

    if (videoHeight > videoWidth) {
      lp.width = screenWidth;
      lp.height = screenHeight;
    } else {
      lp.width = screenWidth;
      float r = videoHeight / (float) videoWidth;
      lp.height = (int) (lp.width * r);
    }
    mVideoView.setLayoutParams(lp);
    mDuration = mVideoView.getDuration();

    VideoTrimmerUtil.maxShootDuration = mMaxDuration > 0 ? Math.min(mMaxDuration * 1000L, mDuration) : mDuration;

    MediaMetadataRetriever mediaMetadataRetriever = new MediaMetadataRetriever();
    mediaMetadataRetriever.setDataSource(mContext, mSourceUri);
    // take first frame
    Bitmap bitmap = mediaMetadataRetriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
    int width = VideoTrimmerUtil.THUMB_HEIGHT * bitmap.getWidth() / bitmap.getHeight();
    VideoTrimmerUtil.mThumbWidth = width;

    if (!getRestoreState()) {
      seekTo((int) mRedProgressBarPos);
    } else {
      setRestoreState(false);
      seekTo((int) mRedProgressBarPos);
    }
    initRangeSeekBarView();
    startShootVideoThumbs(mContext, mSourceUri, mThumbsTotalCount, 0, mDuration);
  }

  private void videoCompleted() {
    seekTo(mLeftProgressPos);
    setPlayPauseViewIcon(false);
  }

  private void onVideoReset() {
    mVideoView.pause();
    setPlayPauseViewIcon(false);
  }

  private void playVideoOrPause() {
    mRedProgressBarPos = mVideoView.getCurrentPosition();
    if (mVideoView.isPlaying()) {
      mVideoView.pause();
      pauseRedProgressAnimation();
    } else {
      mVideoView.start();
      playingRedProgressAnimation();
    }
    setPlayPauseViewIcon(mVideoView.isPlaying());
  }

  public void onVideoPause() {
    if (mVideoView.isPlaying()) {
      seekTo(mLeftProgressPos);//复位
      mVideoView.pause();
      setPlayPauseViewIcon(false);
      mRedProgressIcon.setVisibility(GONE);
    }
  }

  public void setOnTrimVideoListener(VideoTrimListener onTrimVideoListener) {
    mOnTrimVideoListener = onTrimVideoListener;
  }

  private void setUpListeners() {
    findViewById(R.id.cancelBtn).setOnClickListener(view -> {
      mOnTrimVideoListener.onCancel();
    });

    findViewById(R.id.saveBtn).setOnClickListener(view ->  {
      mOnTrimVideoListener.onSave();
    });

    mVideoView.setOnPreparedListener(mp -> {
      // this is called everytime activity goes active, and can fire multiple times
      // so that we create a flag to not run below code more than once
      if (mIsPrepared) {
        return;
      }
      mp.setVideoScalingMode(MediaPlayer.VIDEO_SCALING_MODE_SCALE_TO_FIT);
      videoPrepared(mp);
      mIsPrepared = true;
    });
    mVideoView.setOnCompletionListener(mp -> {
      videoCompleted();
    });
    mPlayView.setOnClickListener(view -> {
      playVideoOrPause();
    });
  }

  public void onSaveClicked() {
    if (mRightProgressPos - mLeftProgressPos < VideoTrimmerUtil.MIN_SHOOT_DURATION) {
      Toast.makeText(mContext, "Video shorter than 3s, can't proceed", Toast.LENGTH_SHORT).show();
    } else {
      mVideoView.pause();
      VideoTrimmerUtil.trim(
        mSourceUri.getPath(),
        StorageUtil.getOutputPath(mContext),
        mDuration,
        mLeftProgressPos,
        mRightProgressPos,
        mOnTrimVideoListener);
    }
  }

  private void seekTo(long msec) {
    mVideoView.seekTo((int) msec);
  }

  private boolean getRestoreState() {
    return isFromRestore;
  }

  public void setRestoreState(boolean fromRestore) {
    isFromRestore = fromRestore;
  }

  private void setPlayPauseViewIcon(boolean isPlaying) {
    mPlayView.setImageResource(isPlaying ? R.drawable.ic_video_pause_black : R.drawable.ic_video_play_black);
  }

  private final RangeSeekBarView.OnRangeSeekBarChangeListener mOnRangeSeekBarChangeListener = new RangeSeekBarView.OnRangeSeekBarChangeListener() {
    @Override public void onRangeSeekBarValuesChanged(RangeSeekBarView bar, long minValue, long maxValue, int action, boolean isMin,
                                                      RangeSeekBarView.Thumb pressedThumb) {
      mLeftProgressPos = minValue + scrollPos;
      mRedProgressBarPos = mLeftProgressPos;

      // when dragging the highlighted section mRightProgressPos in some cases can bigger than mDuration
      // Eg: mDuration=62006, then mRightProgressPos can be 63000
      mRightProgressPos = Math.min(maxValue + scrollPos, mDuration);
      switch (action) {
        case MotionEvent.ACTION_DOWN:
          isSeeking = false;
          break;
        case MotionEvent.ACTION_MOVE:
          isSeeking = true;
          seekTo((int) (pressedThumb == RangeSeekBarView.Thumb.MIN ? mLeftProgressPos : mRightProgressPos));
          break;
        case MotionEvent.ACTION_UP:
          isSeeking = false;
          seekTo((int) mLeftProgressPos);
          break;
        default:
          break;
      }


      mRangeSeekBarView.setStartEndTime(mLeftProgressPos, mRightProgressPos);
    }
  };

  private final RecyclerView.OnScrollListener mOnScrollListener = new RecyclerView.OnScrollListener() {
    @Override
    public void onScrollStateChanged(RecyclerView recyclerView, int newState) {
      super.onScrollStateChanged(recyclerView, newState);
    }

    @Override
    public void onScrolled(RecyclerView recyclerView, int dx, int dy) {
      super.onScrolled(recyclerView, dx, dy);
      isSeeking = false;
      int scrollX = calcScrollXDistance();
      //达不到滑动的距离
      if (Math.abs(lastScrollX - scrollX) < mScaledTouchSlop) {
        isOverScaledTouchSlop = false;
        return;
      }
      isOverScaledTouchSlop = true;
      //初始状态,why ? 因为默认的时候有35dp的空白！
      if (scrollX == -RECYCLER_VIEW_PADDING) {
        scrollPos = 0;
        mLeftProgressPos = mRangeSeekBarView.getSelectedMinValue() + scrollPos;

        // when scrolling the highlighted section mRightProgressPos in some cases can bigger than mDuration
        // Eg: mDuration=62006, then mRightProgressPos can be 63000
        mRightProgressPos = Math.min(mRangeSeekBarView.getSelectedMaxValue() + scrollPos, mDuration);
        mRedProgressBarPos = mLeftProgressPos;
      } else {
        isSeeking = true;
        scrollPos = (long) (mAverageMsPx * (RECYCLER_VIEW_PADDING + scrollX) / VideoTrimmerUtil.mThumbWidth);
        mLeftProgressPos = mRangeSeekBarView.getSelectedMinValue() + scrollPos;

        // when scrolling the highlighted section mRightProgressPos in some cases can bigger than mDuration
        // Eg: mDuration=62006, then mRightProgressPos can be 63000
        mRightProgressPos = Math.min(mRangeSeekBarView.getSelectedMaxValue() + scrollPos, mDuration);
        mRedProgressBarPos = mLeftProgressPos;
        if (mVideoView.isPlaying()) {
          mVideoView.pause();
          setPlayPauseViewIcon(false);
        }
        mRedProgressIcon.setVisibility(GONE);
        seekTo(mLeftProgressPos);

        mRangeSeekBarView.setStartEndTime(mLeftProgressPos, mRightProgressPos);
        mRangeSeekBarView.invalidate();
      }

      lastScrollX = scrollX;
    }
  };

  /**
   * 水平滑动了多少px
   */
  private int calcScrollXDistance() {
    LinearLayoutManager layoutManager = (LinearLayoutManager) mVideoThumbRecyclerView.getLayoutManager();
    int position = layoutManager.findFirstVisibleItemPosition();
    View firstVisibleChildView = layoutManager.findViewByPosition(position);
    int itemWidth = firstVisibleChildView.getWidth();
    return (position) * itemWidth - firstVisibleChildView.getLeft();
  }

  private void playingRedProgressAnimation() {
    pauseRedProgressAnimation();
    playingAnimation();
    mAnimationHandler.post(mAnimationRunnable);
  }

  private void playingAnimation() {
    if (mRedProgressIcon.getVisibility() == View.GONE) {
      mRedProgressIcon.setVisibility(View.VISIBLE);
    }
    final LayoutParams params = (LayoutParams) mRedProgressIcon.getLayoutParams();
    int start = (int) (RECYCLER_VIEW_PADDING + (mRedProgressBarPos - scrollPos) * averagePxMs);
    int end = (int) (RECYCLER_VIEW_PADDING + (mRightProgressPos - scrollPos) * averagePxMs);
    mRedProgressAnimator = ValueAnimator.ofInt(start, end).setDuration((mRightProgressPos - scrollPos) - (mRedProgressBarPos - scrollPos));
    mRedProgressAnimator.setInterpolator(new LinearInterpolator());
    mRedProgressAnimator.addUpdateListener(animation -> {
      params.leftMargin = (int) animation.getAnimatedValue();
      mRedProgressIcon.setLayoutParams(params);
    });
    mRedProgressAnimator.start();
  }

  private void pauseRedProgressAnimation() {
    mRedProgressIcon.clearAnimation();
    if (mRedProgressAnimator != null && mRedProgressAnimator.isRunning()) {
      mAnimationHandler.removeCallbacks(mAnimationRunnable);
      mRedProgressAnimator.cancel();
    }
  }

  private Runnable mAnimationRunnable = () -> updateVideoProgress();

  private void updateVideoProgress() {
    long currentPosition = mVideoView.getCurrentPosition();
    if (currentPosition >= (mRightProgressPos)) {
      mRedProgressBarPos = mLeftProgressPos;
      pauseRedProgressAnimation();
      onVideoPause();
    } else {
      mAnimationHandler.post(mAnimationRunnable);
    }
  }

  @Override
  protected void onDetachedFromWindow() {
    super.onDetachedFromWindow();
    mContext.getCurrentActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);
  }

  /**
   * Cancel trim thread execute action when finish
   */
  @Override public void onDestroy() {
    BackgroundExecutor.cancelAll("", true);
    UiThreadExecutor.cancelAll("");
    mContext.getCurrentActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);
  }

  private int getScreenWidthInPortraitMode() {
    int screenWidth = DeviceUtil.getDeviceWidth();
    int screenHeight = DeviceUtil.getDeviceHeight();

    // Check the current orientation
    int currentOrientation = getResources().getConfiguration().orientation;

    // Swap width and height if the current orientation is landscape
    if (currentOrientation == Configuration.ORIENTATION_LANDSCAPE) {
      return screenHeight;
    }

    return screenWidth;
  }

  private void configure(ReadableMap config) {
    if (config.hasKey("maxDuration")) {
      this.mMaxDuration = config.getInt("maxDuration");
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
}
