package com.videotrim.widgets

import android.content.Context
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.RectF
import android.graphics.SurfaceTexture
import android.graphics.drawable.GradientDrawable
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.AttributeSet
import android.util.Log
import android.util.TypedValue
import android.view.GestureDetector
import android.view.LayoutInflater
import android.view.Gravity
import android.view.MotionEvent
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.RelativeLayout
import android.widget.TextView

import androidx.appcompat.app.AlertDialog

import com.arthenica.ffmpegkit.FFmpegSession
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.UiThreadUtil.runOnUiThread
import com.videotrim.R
import com.videotrim.enums.ErrorCode
import com.videotrim.interfaces.IVideoTrimmerView
import com.videotrim.interfaces.VideoTrimListener
import com.videotrim.utils.MediaMetadataUtil
import com.videotrim.utils.StorageUtil
import com.videotrim.utils.VideoTrimmerUtil
import com.videotrim.utils.VideoTrimmerUtil.RECYCLER_VIEW_PADDING
import com.videotrim.utils.VideoTrimmerUtil.VIDEO_FRAMES_WIDTH

import iknow.android.utils.DeviceUtil
import iknow.android.utils.thread.BackgroundExecutor
import iknow.android.utils.thread.UiThreadExecutor

import java.io.IOException
import java.util.Locale
import androidx.core.graphics.toColorInt

class VideoTrimmerView(
  context: ReactApplicationContext,
  config: ReadableMap?,
  attrs: AttributeSet? = null,
  defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr), IVideoTrimmerView {

  companion object {
    private val TAG: String = VideoTrimmerView::class.java.simpleName
    private const val TIMING_UPDATE_INTERVAL = 30L
  }

  private var mContext: ReactApplicationContext = context
  private lateinit var mVideoView: TextureView
  private var videoSurface: Surface? = null

  private var mediaPlayer: MediaPlayer? = null
  private lateinit var mPlayView: ImageView
  private lateinit var mThumbnailContainer: LinearLayout
  private var mSourceUri: Uri? = null
  private lateinit var mOnTrimVideoListener: VideoTrimListener
  private var mDuration = 0
  private var mMaxDuration = Long.MAX_VALUE
  private var mMinDuration = VideoTrimmerUtil.MIN_SHOOT_DURATION

  private val mTimingHandler = Handler()
  private var mTimingRunnable: Runnable? = null
  private lateinit var currentTimeText: TextView
  private lateinit var startTimeText: TextView
  private lateinit var endTimeText: TextView
  private lateinit var progressIndicator: View
  private lateinit var trimmerContainer: View
  // background of the trimmer container, its width never changes
  // this is to make sure when we calculate position of the progress indicator, we don't need to consider the width of the trimmer container
  private lateinit var trimmerContainerBg: View
  private lateinit var leadingHandle: FrameLayout
  private lateinit var trailingHandle: View
  private lateinit var leadingOverlay: View
  private lateinit var trailingOverlay: View
  private lateinit var trimmerContainerWrapper: RelativeLayout

  private var startTime = 0L
  private var endTime = 0L
  private var zoomOnWaitingDuration = 5000L

  private var vibrator: Vibrator? = null
  private var didClampWhilePanning = false

  // zoom
  private var isZoomedIn = false
  private val zoomWaitTimer = Handler()
  private var zoomRunnable: Runnable? = null
  private var zoomedInRangeStart = 0L
  private var zoomedInRangeDuration = 0L
  private var isTrimmingLeading = false

  // range drag
  private var isRangeDragging = false
  private var rangeDragInitialRawX = 0f
  private var rangeDragInitialStartTime = 0L
  private var rangeDragInitialEndTime = 0L
  private lateinit var rangeDragGestureDetector: GestureDetector

  // thumbnail caching for zoom functionality
  private val cachedFullViewThumbnails = mutableListOf<ImageView>()
  @Volatile
  private var isGeneratingThumbnails = false

  private var mediaMetadataRetriever: MediaMetadataRetriever? = null
  private val retrieverLock = Object()
  @Volatile private var retrieverReleased = false
  private lateinit var loadingIndicator: ProgressBar
  private lateinit var saveBtn: TextView
  private lateinit var cancelBtn: TextView
  private lateinit var audioBannerView: FrameLayout
  private var isVideoType = true
  private lateinit var failToLoadBtn: ImageView

  private var mOutputExt = "mp4"
  private var enableHapticFeedback = true
  private var enablePreciseTrimming = false
  private var autoplay = false
  private var jumpToPositionOnLoad = 0L
  private lateinit var headerView: FrameLayout
  private lateinit var headerText: TextView
  private var ffmpegSession: FFmpegSession? = null
  private var alertOnFailToLoad = true
  private var alertOnFailTitle = "Error"
  private var alertOnFailMessage = "Fail to load media. Possibly invalid file or no network connection"
  private var alertOnFailCloseText = "Close"
  private var currentSelectedhandle: View? = null

  // Transform state
  var rotationCount = 0
    private set
  var isFlipped = false
    private set
  private var isCropActive = false
  private var cumulativeRotationDeg = 0f

  private data class TransformSnapshot(
    val rotationCount: Int,
    val isFlipped: Boolean,
    val isCropActive: Boolean,
    val cropNormalized: RectF?,
    val cumulativeRotationDeg: Float
  )
  private val undoStack = mutableListOf<TransformSnapshot>()
  private val redoStack = mutableListOf<TransformSnapshot>()
  private var preCropSnapshot: TransformSnapshot? = null

  private lateinit var transformRow: LinearLayout
  private lateinit var flipBtn: ImageView
  private lateinit var rotateBtn: ImageView
  private lateinit var cropBtn: ImageView
  private lateinit var undoBtn: ImageView
  private lateinit var redoBtn: ImageView
  private lateinit var videoContainer: FrameLayout
  private var cropOverlay: CropOverlayView? = null

  private lateinit var trimmerView: RelativeLayout

  private var trimmerColor = context.getString(R.string.trim_color).toColorInt()
  private var handleIconColor = Color.BLACK
  private lateinit var leadingChevron: ImageView
  private lateinit var trailingChevron: ImageView

  init {
    init(context, config)
  }

  private fun init(context: ReactApplicationContext, config: ReadableMap?) {
    mContext = context

    context.currentActivity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
    LayoutInflater.from(context).inflate(R.layout.video_trimmer_view, this, true)
    vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

    initializeViews()
    if (config != null) configure(config)
    setUpListeners()
    initRangeDragDetector()
    setProgressIndicatorTouchListener()
  }

  private fun initRangeDragDetector() {
    rangeDragGestureDetector = GestureDetector(mContext, object : GestureDetector.SimpleOnGestureListener() {
      override fun onLongPress(e: MotionEvent) {
        isRangeDragging = true
        rangeDragInitialRawX = e.rawX
        rangeDragInitialStartTime = startTime
        rangeDragInitialEndTime = endTime
        playHapticFeedback(true)
        fadeOutProgressIndicator()
      }
    })
  }

  private fun initializeViews() {
    mThumbnailContainer = findViewById(R.id.thumbnailContainer)
    mVideoView = findViewById(R.id.video_loader)
    mPlayView = findViewById(R.id.icon_video_play)
    startTimeText = findViewById(R.id.startTime)
    currentTimeText = findViewById(R.id.currentTime)
    endTimeText = findViewById(R.id.endTime)
    progressIndicator = findViewById(R.id.progressIndicator)
    trimmerContainer = findViewById(R.id.trimmerContainer)
    trimmerContainerBg = findViewById(R.id.trimmerContainerBg)
    leadingHandle = findViewById(R.id.leadingHandle)
    trailingHandle = findViewById(R.id.trailingHandle)
    leadingOverlay = findViewById(R.id.leadingOverlay)
    trailingOverlay = findViewById(R.id.trailingOverlay)

    trimmerContainerWrapper = findViewById(R.id.trimmerContainerWrapper)
    trimmerContainerWrapper.visibility = View.INVISIBLE
    trimmerContainerWrapper.alpha = 0f

    loadingIndicator = findViewById(R.id.loadingIndicator)
    saveBtn = findViewById(R.id.saveBtn)
    cancelBtn = findViewById(R.id.cancelBtn)
    audioBannerView = findViewById(R.id.audioBannerView)
    failToLoadBtn = findViewById(R.id.failToLoadBtn)

    headerView = findViewById(R.id.headerView)
    headerText = findViewById(R.id.headerText)

    trimmerView = findViewById(R.id.trimmerView)

    leadingChevron = findViewById(R.id.leadingChevron)
    trailingChevron = findViewById(R.id.trailingChevron)

    transformRow = findViewById(R.id.transformRow)
    flipBtn = findViewById(R.id.flipBtn)
    rotateBtn = findViewById(R.id.rotateBtn)
    cropBtn = findViewById(R.id.cropBtn)
    undoBtn = findViewById(R.id.undoBtn)
    redoBtn = findViewById(R.id.redoBtn)
    videoContainer = findViewById(R.id.videoContainer)
  }

  fun initByURI(videoURI: Uri) {
    mSourceUri = videoURI

    if (isVideoType) {
      if (mVideoView.isAvailable) {
        setupVideoPlayer(mVideoView.surfaceTexture!!, videoURI)
      }
      mVideoView.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
        override fun onSurfaceTextureAvailable(st: SurfaceTexture, w: Int, h: Int) {
          setupVideoPlayer(st, videoURI)
        }
        override fun onSurfaceTextureSizeChanged(st: SurfaceTexture, w: Int, h: Int) {}
        override fun onSurfaceTextureDestroyed(st: SurfaceTexture): Boolean = true
        override fun onSurfaceTextureUpdated(st: SurfaceTexture) {}
      }
    } else {
      mVideoView.visibility = View.GONE
      audioBannerView.alpha = 0f
      audioBannerView.visibility = View.VISIBLE
      audioBannerView.animate().alpha(1f).setDuration(500).start()

      mediaPlayer = MediaPlayer()
      try {
        mediaPlayer!!.setDataSource(videoURI.toString())
        mediaPlayer!!.setOnPreparedListener { mediaPrepared() }
        mediaPlayer!!.setOnCompletionListener { mediaCompleted() }
        mediaPlayer!!.setOnErrorListener { mp, what, extra -> onFailToLoadMedia(mp, what, extra) }
        mediaPlayer!!.prepareAsync()
      } catch (e: IOException) {
        e.printStackTrace()
        mediaFailed()
        mOnTrimVideoListener.onError("Error initializing audio player. Please try again.", ErrorCode.FAIL_TO_INITIALIZE_AUDIO_PLAYER)
      }
    }
  }

  private fun setupVideoPlayer(surfaceTexture: SurfaceTexture, videoURI: Uri) {
    if (mediaPlayer != null) return
    val mp = MediaPlayer()
    try {
      videoSurface = Surface(surfaceTexture)
      mp.setSurface(videoSurface)
      mp.setDataSource(mContext, videoURI)
      mp.setOnPreparedListener {
        mediaPlayer = mp
        mediaPrepared()
      }
      mp.setOnErrorListener { mpCb, what, extra -> onFailToLoadMedia(mpCb, what, extra) }
      mp.setOnCompletionListener { mediaCompleted() }
      mp.prepareAsync()
    } catch (e: Exception) {
      e.printStackTrace()
      mediaFailed()
      mOnTrimVideoListener.onError("Error initializing video player.", ErrorCode.FAIL_TO_LOAD_MEDIA)
    }
  }

  private fun updateVideoViewSize() {
    val vw = mediaPlayer?.videoWidth ?: return
    val vh = mediaPlayer?.videoHeight ?: return
    if (vw <= 0 || vh <= 0) return

    videoContainer.post {
      val cw = containerContentWidth().toInt()
      val ch = containerContentHeight().toInt()
      if (cw <= 0 || ch <= 0) return@post

      val margin = bracketOverflow()
      val availW = cw - 2 * margin
      val availH = ch - 2 * margin
      if (availW <= 0 || availH <= 0) return@post

      val videoAR = vw.toFloat() / vh
      val containerAR = availW.toFloat() / availH
      val newW: Int
      val newH: Int
      if (videoAR > containerAR) {
        newW = availW
        newH = (availW / videoAR).toInt()
      } else {
        newH = availH
        newW = (availH * videoAR).toInt()
      }
      mVideoView.layoutParams = FrameLayout.LayoutParams(newW, newH, Gravity.CENTER)
    }
  }

  private fun onFailToLoadMedia(mp: MediaPlayer, what: Int, extra: Int): Boolean {
    mediaFailed()
    mOnTrimVideoListener.onError("Error loading media file. Please try again.", ErrorCode.FAIL_TO_LOAD_MEDIA)
    if (alertOnFailToLoad) {
      val activity = mContext.currentActivity ?: return true
      val builder = AlertDialog.Builder(activity)
      builder.setMessage(alertOnFailMessage)
      builder.setTitle(alertOnFailTitle)
      builder.setCancelable(false)
      builder.setPositiveButton(alertOnFailCloseText) { dialog, _ -> dialog.cancel() }

      val alertDialog = builder.create()
      alertDialog.show()
    }
    return true
  }

  private fun startShootVideoThumbs(context: Context, totalThumbsCount: Int, startPosition: Long, endPosition: Long) {
    mThumbnailContainer.removeAllViews()
    cachedFullViewThumbnails.clear()

    val containerContentWidth = mThumbnailContainer.width - mThumbnailContainer.paddingLeft - mThumbnailContainer.paddingRight
    val effectiveWidth = if (containerContentWidth > 0) containerContentWidth else VideoTrimmerUtil.VIDEO_FRAMES_WIDTH
    val baseThumbWidth = effectiveWidth / totalThumbsCount
    val remainder = effectiveWidth % totalThumbsCount

    VideoTrimmerUtil.shootVideoThumbInBackground(mediaMetadataRetriever!!, totalThumbsCount, startPosition, endPosition) { bitmap, interval ->
      if (bitmap != null) {
        runOnUiThread {
          val index = mThumbnailContainer.childCount
          val width = if (index < remainder) baseThumbWidth + 1 else baseThumbWidth
          val layoutParams = LinearLayout.LayoutParams(width, LayoutParams.MATCH_PARENT)

          val thumbImageView = ImageView(context)
          thumbImageView.setImageBitmap(bitmap)
          thumbImageView.scaleType = ImageView.ScaleType.CENTER_CROP
          thumbImageView.layoutParams = layoutParams
          mThumbnailContainer.addView(thumbImageView)

          val cachedView = ImageView(context)
          cachedView.setImageBitmap(bitmap)
          cachedView.scaleType = ImageView.ScaleType.CENTER_CROP
          cachedView.layoutParams = LinearLayout.LayoutParams(width, LayoutParams.MATCH_PARENT)
          cachedFullViewThumbnails.add(cachedView)
        }
      }
    }
  }

  private fun mediaPrepared() {
    mDuration = mediaPlayer!!.duration
    mMaxDuration = mMaxDuration.coerceAtMost(mDuration.toLong())

    if (isVideoType) {
      updateVideoViewSize()

      mediaMetadataRetriever = MediaMetadataUtil.getMediaMetadataRetriever(mSourceUri.toString())
      if (mediaMetadataRetriever == null) {
        mOnTrimVideoListener.onError("Error when retrieving video info. Please try again.", ErrorCode.FAIL_TO_GET_VIDEO_INFO)
        return
      }

      val bitmap = mediaMetadataRetriever!!.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)

      if (bitmap != null) {
        val bitmapHeight = if (bitmap.height > 0) bitmap.height else VideoTrimmerUtil.THUMB_HEIGHT
        val bitmapWidth = if (bitmap.width > 0) bitmap.width else VideoTrimmerUtil.THUMB_WIDTH
        VideoTrimmerUtil.mThumbWidth = VideoTrimmerUtil.THUMB_HEIGHT * bitmapWidth / bitmapHeight
      }

      VideoTrimmerUtil.SCREEN_WIDTH_FULL = getScreenWidthInPortraitMode()
      VideoTrimmerUtil.VIDEO_FRAMES_WIDTH = VideoTrimmerUtil.SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2
      VideoTrimmerUtil.MAX_COUNT_RANGE = if (VideoTrimmerUtil.mThumbWidth != 0)
        maxOf(VIDEO_FRAMES_WIDTH / VideoTrimmerUtil.mThumbWidth, VideoTrimmerUtil.MAX_COUNT_RANGE)
      else
        VideoTrimmerUtil.MAX_COUNT_RANGE

      startShootVideoThumbs(mContext, VideoTrimmerUtil.MAX_COUNT_RANGE, 0, mDuration.toLong())
    }

    endTime = if (mMaxDuration < mDuration) mMaxDuration else mDuration.toLong()
    updateHandlePositions()

    loadingIndicator.visibility = View.GONE
    mPlayView.visibility = View.VISIBLE
    saveBtn.visibility = View.VISIBLE

    if (jumpToPositionOnLoad > 0) {
      seekTo(if (jumpToPositionOnLoad > mDuration) mDuration.toLong() else jumpToPositionOnLoad, true)
    }

    if (autoplay) {
      playOrPause()
    }

    if (isVideoType) {
      transformRow.alpha = 0f
      transformRow.visibility = View.VISIBLE
      transformRow.animate().alpha(1f).setDuration(250).start()
      updateUndoRedoButtons()
    }

    mOnTrimVideoListener.onLoad(mDuration)
    ignoreSystemGestureForView(trimmerView)
  }

  private fun updateGradientColors(startColor: Int, endColor: Int) {
    val gradientDrawable = GradientDrawable().apply {
      shape = GradientDrawable.RECTANGLE
      cornerRadius = 6f
      colors = intArrayOf(startColor, endColor)
      orientation = GradientDrawable.Orientation.LEFT_RIGHT
    }
    mThumbnailContainer.background = gradientDrawable
  }

  private fun mediaFailed() {
    loadingIndicator.visibility = View.GONE
    failToLoadBtn.visibility = View.VISIBLE
  }

  private fun updateHandlePositions() {
    val leadingHandleX = positionForTime(startTime)
    val trailingHandleX = positionForTime(endTime)

    leadingHandle.x = leadingHandleX
    trailingHandle.x = trailingHandleX + trailingHandle.width

    updateTrimmerContainerWidth()
    updateCurrentTime(false)

    trimmerContainerWrapper.visibility = View.VISIBLE
    trimmerContainerWrapper.animate().alpha(1f).setDuration(250).start()
  }

  private fun mediaCompleted() {
    onMediaPause()
    // when mediaCompleted is called, the endTime may not be exactly at the end of the video (can be slightly before), therefore we should seek to exact position on ended
    seekTo(endTime, true)
  }

  private fun playOrPause() {
    val player = mediaPlayer ?: return
    if (player.isPlaying) {
      onMediaPause()
    } else {
      if (player.currentPosition >= endTime) {
        seekTo(startTime, true)
      }
      player.start()
      startTimingRunnable()
    }
    setPlayPauseViewIcon(player.isPlaying)
  }

  fun onMediaPause() {
    mTimingRunnable?.let { mTimingHandler.removeCallbacks(it) }
    val player = mediaPlayer ?: return
    if (player.isPlaying) {
      player.pause()
    }
    setPlayPauseViewIcon(false)
  }

  fun setOnTrimVideoListener(onTrimVideoListener: VideoTrimListener) {
    mOnTrimVideoListener = onTrimVideoListener
  }

  private fun setUpListeners() {
    cancelBtn.setOnClickListener { mOnTrimVideoListener.onCancel() }
    saveBtn.setOnClickListener { mOnTrimVideoListener.onSave() }
    mPlayView.setOnClickListener { playOrPause() }
    setHandleTouchListener(leadingHandle, true)
    setHandleTouchListener(trailingHandle, false)

    flipBtn.setOnClickListener { onFlipTapped() }
    rotateBtn.setOnClickListener { onRotateTapped() }
    cropBtn.setOnClickListener { onCropTapped() }
    undoBtn.setOnClickListener { onUndoTapped() }
    redoBtn.setOnClickListener { onRedoTapped() }

    cropBtn.setColorFilter(Color.argb(128, 255, 255, 255), android.graphics.PorterDuff.Mode.SRC_IN)
    undoBtn.setColorFilter(Color.argb(128, 255, 255, 255), android.graphics.PorterDuff.Mode.SRC_IN)
    redoBtn.setColorFilter(Color.argb(128, 255, 255, 255), android.graphics.PorterDuff.Mode.SRC_IN)
  }

  fun onSaveClicked() {
    onMediaPause()
    val vw = mediaPlayer?.videoWidth ?: 0
    val vh = mediaPlayer?.videoHeight ?: 0
    val bitrate = synchronized(retrieverLock) {
      if (retrieverReleased) 0L
      else mediaMetadataRetriever
        ?.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
        ?.toLongOrNull() ?: 0L
    }
    ffmpegSession = VideoTrimmerUtil.trim(
      mSourceUri.toString(),
      StorageUtil.getOutputPath(mContext, mOutputExt),
      mDuration,
      startTime,
      endTime,
      rotationCount,
      isFlipped,
      getCropNormalizedRect(),
      vw,
      vh,
      bitrate,
      enablePreciseTrimming,
      mOnTrimVideoListener
    )
  }

  fun onCancelTrimClicked() {
    if (ffmpegSession != null) {
      ffmpegSession!!.cancel()
    } else {
      mOnTrimVideoListener.onCancelTrim()
    }
  }

  private fun seekTo(msec: Long, needUpdateProgress: Boolean) {
    val player = mediaPlayer ?: return
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      player.seekTo(msec, MediaPlayer.SEEK_CLOSEST)
    } else {
      player.seekTo(msec.toInt())
    }
    updateCurrentTime(needUpdateProgress)
  }

  private fun setPlayPauseViewIcon(isPlaying: Boolean) {
    mPlayView.setImageResource(if (isPlaying) R.drawable.pause_fill else R.drawable.play_fill)
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    mContext.currentActivity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
  }

  override fun onDestroy() {
    isGeneratingThumbnails = false
    BackgroundExecutor.cancelAll("", true)
    BackgroundExecutor.cancelAll("progressive_thumbs", true)
    UiThreadExecutor.cancelAll("")
    mContext.currentActivity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
    mTimingRunnable?.let { mTimingHandler.removeCallbacks(it) }
    zoomRunnable?.let { zoomWaitTimer.removeCallbacks(it) }

    cachedFullViewThumbnails.clear()

    cropOverlay?.onCropBegan = null
    cropOverlay?.onCropEnded = null
    cropOverlay?.onCropChanged = null
    cropOverlay = null
    undoStack.clear()
    redoStack.clear()
    cumulativeRotationDeg = 0f

    synchronized(retrieverLock) {
      retrieverReleased = true
      try {
        mediaMetadataRetriever?.release()
      } catch (e: Exception) {
        e.printStackTrace()
      }
    }

    try {
      mediaPlayer?.stop()
      mediaPlayer?.release()
    } catch (e: IllegalStateException) {
      e.printStackTrace()
      Log.d(TAG, "onDestroy mediaPlayer is already released")
    }

    try {
      videoSurface?.release()
    } catch (_: Exception) {}
    videoSurface = null
  }

  private fun getScreenWidthInPortraitMode(): Int {
    val screenWidth = DeviceUtil.getDeviceWidth()
    val screenHeight = DeviceUtil.getDeviceHeight()
    val currentOrientation = resources.configuration.orientation
    return if (currentOrientation == Configuration.ORIENTATION_LANDSCAPE) screenHeight else screenWidth
  }

  private fun configure(config: ReadableMap) {
    if (config.hasKey("maxDuration") && config.getDouble("maxDuration") > 0) {
      mMaxDuration = maxOf(0, config.getDouble("maxDuration").toLong())
    }

    if (config.hasKey("minDuration") && config.getDouble("minDuration") > 0) {
      mMinDuration = maxOf(1000L, config.getDouble("minDuration").toLong())
    }

    cancelBtn.text = config.getString("cancelButtonText")
    saveBtn.text = config.getString("saveButtonText")
    isVideoType = config.hasKey("type") && config.getString("type") == "video"
    println("isVideoType: $isVideoType")

    mOutputExt = if (config.hasKey("outputExt")) config.getString("outputExt") ?: "mp4" else "mp4"
    if (!isVideoType) {
      mOutputExt = "wav"
    }
    enableHapticFeedback = config.hasKey("enableHapticFeedback") && config.getBoolean("enableHapticFeedback")
    enablePreciseTrimming = config.hasKey("enablePreciseTrimming") && config.getBoolean("enablePreciseTrimming")
    autoplay = config.hasKey("autoplay") && config.getBoolean("autoplay")

    if (config.hasKey("jumpToPositionOnLoad") && config.getDouble("jumpToPositionOnLoad") > 0) {
      jumpToPositionOnLoad = maxOf(0, (config.getDouble("jumpToPositionOnLoad") * 1000L).toLong())
    }
    headerText.text = if (config.hasKey("headerText")) config.getString("headerText") ?: "" else ""

    var textSize = if (config.hasKey("headerTextSize")) config.getInt("headerTextSize") else 16
    if (textSize < 0) {
      textSize = 16
    }

    headerText.setTextSize(TypedValue.COMPLEX_UNIT_DIP, textSize.toFloat())
    headerText.setTextColor(if (config.hasKey("headerTextColor")) config.getInt("headerTextColor") else Color.BLACK)

    headerView.visibility = View.VISIBLE
    alertOnFailToLoad = config.hasKey("alertOnFailToLoad") && config.getBoolean("alertOnFailToLoad")
    alertOnFailTitle = if (config.hasKey("alertOnFailTitle")) config.getString("alertOnFailTitle") ?: "Error" else "Error"
    alertOnFailMessage = if (config.hasKey("alertOnFailMessage")) config.getString("alertOnFailMessage") ?: "Fail to load media. Possibly invalid file or no network connection" else "Fail to load media. Possibly invalid file or no network connection"
    alertOnFailCloseText = if (config.hasKey("alertOnFailCloseText")) config.getString("alertOnFailCloseText") ?: "Close" else "Close"

    if (config.hasKey("zoomOnWaitingDuration") && config.getDouble("zoomOnWaitingDuration") > 0) {
      zoomOnWaitingDuration = config.getDouble("zoomOnWaitingDuration").toLong()
      Log.d(TAG, "Configured zoom on waiting duration: ${zoomOnWaitingDuration / 1000.0} seconds")
    }

    trimmerColor = if (config.hasKey("trimmerColor")) config.getInt("trimmerColor") else context.getString(
      R.string.trim_color
    ).toColorInt()
    handleIconColor = if (config.hasKey("handleIconColor")) config.getInt("handleIconColor") else Color.BLACK

    applyTrimmerColor()
  }

  private fun applyTrimmerColor() {
    val borderDrawable = GradientDrawable().apply {
      shape = GradientDrawable.RECTANGLE
      setColor(Color.TRANSPARENT)
      setStroke(dpToPx(4), trimmerColor)
    }
    trimmerContainer.background = borderDrawable

    val leadingHandleDrawable = GradientDrawable().apply {
      shape = GradientDrawable.RECTANGLE
      setColor(trimmerColor)
      cornerRadii = floatArrayOf(dpToPx(6).toFloat(), dpToPx(6).toFloat(), 0f, 0f, 0f, 0f, dpToPx(6).toFloat(), dpToPx(6).toFloat())
    }
    leadingHandle.background = leadingHandleDrawable

    val trailingHandleDrawable = GradientDrawable().apply {
      shape = GradientDrawable.RECTANGLE
      setColor(trimmerColor)
      cornerRadii = floatArrayOf(0f, 0f, dpToPx(6).toFloat(), dpToPx(6).toFloat(), dpToPx(6).toFloat(), dpToPx(6).toFloat(), 0f, 0f)
    }
    trailingHandle.background = trailingHandleDrawable

    leadingChevron.setColorFilter(handleIconColor, android.graphics.PorterDuff.Mode.SRC_IN)
    trailingChevron.setColorFilter(handleIconColor, android.graphics.PorterDuff.Mode.SRC_IN)
  }

  private fun dpToPx(dp: Int): Int {
    return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(), resources.displayMetrics).toInt()
  }

  private fun startTimingRunnable() {
    mTimingRunnable = object : Runnable {
      override fun run() {
        try {
          val currentPosition = mediaPlayer!!.currentPosition
          if (currentPosition >= endTime) {
            onMediaPause()
            seekTo(endTime, true)
          } else {
            updateCurrentTime(true)
            mTimingHandler.postDelayed(this, TIMING_UPDATE_INTERVAL)
          }
        } catch (e: IllegalStateException) {
          e.printStackTrace()
          mTimingRunnable?.let { mTimingHandler.removeCallbacks(it) }
        }
      }
    }
    mTimingHandler.postDelayed(mTimingRunnable!!, TIMING_UPDATE_INTERVAL)
  }

  private fun updateCurrentTime(needUpdateProgress: Boolean) {
    var currentPosition = mediaPlayer!!.currentPosition
    val duration = mDuration

    when {
      currentPosition >= duration - 100 -> currentPosition = duration
      currentPosition >= endTime - 100 -> currentPosition = endTime.toInt()
      currentPosition <= startTime + 100 -> currentPosition = startTime.toInt()
    }

    currentTimeText.text = formatTime(currentPosition)
    startTimeText.text = formatTime(startTime.toInt())
    endTimeText.text = formatTime(endTime.toInt())

    if (needUpdateProgress) {
      val indicatorPosition: Float

      if (isZoomedIn) {
        val visibleRangeStart = getVisibleRangeStart()
        val visibleRangeDuration = getVisibleRangeDuration()

        var clampedPosition = currentPosition
        if (clampedPosition < visibleRangeStart || clampedPosition > visibleRangeStart + visibleRangeDuration) {
          clampedPosition = maxOf(visibleRangeStart, minOf(visibleRangeStart + visibleRangeDuration, currentPosition.toLong())).toInt()
        }

        val ratio = if (visibleRangeDuration > 0) (clampedPosition - visibleRangeStart).toFloat() / visibleRangeDuration else 0f
        indicatorPosition = ratio * (trimmerContainerBg.width - progressIndicator.width) + leadingHandle.width
      } else {
        indicatorPosition = if (mDuration > 0)
          currentPosition.toFloat() / mDuration * (trimmerContainerBg.width - progressIndicator.width) + leadingHandle.width
        else
          leadingHandle.width.toFloat()
      }

      val leftBoundary = leadingHandle.x + leadingHandle.width
      val rightBoundary = trailingHandle.x - progressIndicator.width
      val boundedPosition = maxOf(leftBoundary, minOf(rightBoundary, indicatorPosition))

      when (currentSelectedhandle) {
        leadingHandle -> progressIndicator.x = maxOf(leftBoundary, boundedPosition)
        trailingHandle -> progressIndicator.x = minOf(rightBoundary, boundedPosition)
        else -> progressIndicator.x = boundedPosition
      }
    }
  }

  private fun formatTime(milliseconds: Int): String {
    val totalSeconds = milliseconds / 1000
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    val millis = milliseconds % 1000
    return String.format(Locale.getDefault(), "%d:%02d.%03d", minutes, seconds, millis)
  }

  @Suppress("ClickableViewAccessibility")
  private fun setProgressIndicatorTouchListener() {
    trimmerContainerBg.setOnTouchListener { view, event ->
      rangeDragGestureDetector.onTouchEvent(event)

      when (event.action) {
        MotionEvent.ACTION_DOWN -> {
          isRangeDragging = false
          didClampWhilePanning = false
          onMediaPause()
          onTrimmerContainerPanned(event)
          playHapticFeedback(true)
        }
        MotionEvent.ACTION_MOVE -> {
          if (isRangeDragging) {
            onRangeDrag(event)
          } else {
            onTrimmerContainerPanned(event)
          }
        }
        MotionEvent.ACTION_UP -> {
          if (isRangeDragging) {
            isRangeDragging = false
            fadeInProgressIndicator()
            updateCurrentTime(true)
          }
          view.performClick()
        }
        else -> return@setOnTouchListener false
      }
      true
    }
  }

  private fun onTrimmerContainerPanned(event: MotionEvent) {
    var newX = event.rawX
    var didClamp = false

    val leftBoundary = leadingHandle.x + leadingHandle.width
    val rightBoundary = trailingHandle.x - progressIndicator.width

    newX = maxOf(leftBoundary, newX)
    newX = minOf(rightBoundary, newX)

    if (newX <= leftBoundary || newX >= rightBoundary) {
      didClamp = true
    }

    if (didClamp && !didClampWhilePanning) {
      playHapticFeedback(false)
    }
    didClampWhilePanning = didClamp

    progressIndicator.x = newX

    val indicatorPosition = newX - trimmerContainerBg.x

    val indicatorPositionPercent: Float
    val newVideoPosition: Long

    if (isZoomedIn) {
      indicatorPositionPercent = indicatorPosition / (trimmerContainerBg.width - progressIndicator.width)
      val visibleStart = getVisibleRangeStart()
      val visibleDuration = getVisibleRangeDuration()
      newVideoPosition = visibleStart + (indicatorPositionPercent * visibleDuration).toLong()
    } else {
      indicatorPositionPercent = indicatorPosition / (trimmerContainerBg.width - progressIndicator.width)
      newVideoPosition = (indicatorPositionPercent * mDuration).toLong()
    }

    seekTo(newVideoPosition, false)
  }

  private fun onRangeDrag(event: MotionEvent) {
    val deltaX = event.rawX - rangeDragInitialRawX
    val containerWidth = trimmerContainerBg.width.toFloat()
    if (containerWidth <= 0) return

    val rangeDuration = rangeDragInitialEndTime - rangeDragInitialStartTime
    val deltaTime = if (isZoomedIn) {
      (deltaX / containerWidth * zoomedInRangeDuration).toLong()
    } else {
      (deltaX / containerWidth * mDuration).toLong()
    }

    var newStart = rangeDragInitialStartTime + deltaTime
    var newEnd = newStart + rangeDuration

    var didClamp = false
    if (newStart < 0) {
      newStart = 0
      newEnd = rangeDuration
      didClamp = true
    }
    if (newEnd > mDuration) {
      newEnd = mDuration.toLong()
      newStart = newEnd - rangeDuration
      didClamp = true
    }

    if (didClamp && !didClampWhilePanning) {
      playHapticFeedback(false)
    }
    didClampWhilePanning = didClamp

    startTime = newStart
    endTime = newEnd
    updateHandlePositions()
    seekTo(startTime, false)
  }

  @Suppress("ClickableViewAccessibility")
  private fun setHandleTouchListener(handle: View, isLeading: Boolean) {
    handle.setOnTouchListener { view, event ->
      val draggingDisabled = mDuration < mMinDuration
      when (event.action) {
        MotionEvent.ACTION_DOWN -> {
          currentSelectedhandle = handle
          didClampWhilePanning = false
          onMediaPause()
          fadeOutProgressIndicator()
          seekTo(if (isLeading) startTime else endTime, true)
          playHapticFeedback(true)
          isTrimmingLeading = isLeading
        }
        MotionEvent.ACTION_MOVE -> {
          if (draggingDisabled) return@setOnTouchListener false

          var didClamp = false
          var newX = event.rawX - view.width.toFloat() / 2

          if (isLeading) {
            newX = maxOf(0f, minOf(newX, trailingHandle.x - view.width))
          } else {
            newX = minOf(trimmerContainerBg.width.toFloat() + view.width, maxOf(newX, leadingHandle.x + view.width))
          }

          view.x = newX

          if (isLeading) {
            val newStartTime = timeForPosition(newX)
            val duration = endTime - newStartTime
            when {
              duration in mMinDuration..mMaxDuration -> {
                startTime = newStartTime
                val indicatorX = newX + view.width
                val leftBoundary = leadingHandle.x + leadingHandle.width
                val rightBoundary = trailingHandle.x - progressIndicator.width
                progressIndicator.x = maxOf(leftBoundary, minOf(rightBoundary, indicatorX))
              }
              duration < mMinDuration -> {
                didClamp = true
                startTime = endTime - mMinDuration
                if (isZoomedIn) {
                  val indicatorX = newX + view.width
                  val leftBoundary = leadingHandle.x + leadingHandle.width
                  val rightBoundary = trailingHandle.x - progressIndicator.width
                  progressIndicator.x = maxOf(leftBoundary, minOf(rightBoundary, indicatorX))
                } else {
                  view.x = positionForTime(startTime)
                  val indicatorX = view.x + view.width
                  val leftBoundary = leadingHandle.x + leadingHandle.width
                  val rightBoundary = trailingHandle.x - progressIndicator.width
                  progressIndicator.x = maxOf(leftBoundary, minOf(rightBoundary, indicatorX))
                }
              }
              else -> {
                didClamp = true
                startTime = endTime - mMaxDuration
                if (isZoomedIn) {
                  val indicatorX = newX + view.width
                  val leftBoundary = leadingHandle.x + leadingHandle.width
                  val rightBoundary = trailingHandle.x - progressIndicator.width
                  progressIndicator.x = maxOf(leftBoundary, minOf(rightBoundary, indicatorX))
                } else {
                  view.x = positionForTime(startTime)
                  val indicatorX = view.x + view.width
                  val leftBoundary = leadingHandle.x + leadingHandle.width
                  val rightBoundary = trailingHandle.x - progressIndicator.width
                  progressIndicator.x = maxOf(leftBoundary, minOf(rightBoundary, indicatorX))
                }
              }
            }
          } else {
            val newEndTime = timeForPosition(newX - view.width)
            val duration = newEndTime - startTime
            when {
              duration in mMinDuration..mMaxDuration -> {
                endTime = newEndTime
                val indicatorX = newX - progressIndicator.width
                val leftBoundary = leadingHandle.x + leadingHandle.width
                val rightBoundary = trailingHandle.x - progressIndicator.width
                progressIndicator.x = maxOf(leftBoundary, minOf(rightBoundary, indicatorX))
              }
              duration < mMinDuration -> {
                didClamp = true
                endTime = startTime + mMinDuration
                if (isZoomedIn) {
                  val indicatorX = newX - progressIndicator.width
                  val leftBoundary = leadingHandle.x + leadingHandle.width
                  val rightBoundary = trailingHandle.x - progressIndicator.width
                  progressIndicator.x = maxOf(leftBoundary, minOf(rightBoundary, indicatorX))
                } else {
                  view.x = positionForTime(endTime) + view.width
                  val indicatorX = view.x - progressIndicator.width
                  val leftBoundary = leadingHandle.x + leadingHandle.width
                  val rightBoundary = trailingHandle.x - progressIndicator.width
                  progressIndicator.x = maxOf(leftBoundary, minOf(rightBoundary, indicatorX))
                }
              }
              else -> {
                didClamp = true
                endTime = startTime + mMaxDuration
                if (isZoomedIn) {
                  val indicatorX = newX - progressIndicator.width
                  val leftBoundary = leadingHandle.x + leadingHandle.width
                  val rightBoundary = trailingHandle.x - progressIndicator.width
                  progressIndicator.x = maxOf(leftBoundary, minOf(rightBoundary, indicatorX))
                } else {
                  view.x = positionForTime(endTime) + view.width
                  val indicatorX = view.x - progressIndicator.width
                  val leftBoundary = leadingHandle.x + leadingHandle.width
                  val rightBoundary = trailingHandle.x - progressIndicator.width
                  progressIndicator.x = maxOf(leftBoundary, minOf(rightBoundary, indicatorX))
                }
              }
            }
          }

          if (didClamp && !didClampWhilePanning) {
            playHapticFeedback(false)
          }
          didClampWhilePanning = didClamp

          updateTrimmerContainerWidth()
          seekTo(if (isLeading) startTime else endTime, false)

          startZoomWaitTimer()
        }
        MotionEvent.ACTION_UP -> {
          stopZoomIfNeeded()
          fadeInProgressIndicator()
          view.performClick()
        }
        else -> return@setOnTouchListener false
      }
      true
    }
  }

  private fun fadeOutProgressIndicator() {
    progressIndicator.animate().alpha(0f).setDuration(250).withEndAction { progressIndicator.visibility = View.INVISIBLE }.start()
  }

  private fun fadeInProgressIndicator() {
    progressIndicator.visibility = View.VISIBLE
    progressIndicator.animate().alpha(1f).setDuration(250).start()
  }

  private fun updateTrimmerContainerWidth() {
    val left = (leadingHandle.x + leadingHandle.width).toInt()
    val right = trimmerContainerBg.width - kotlin.math.ceil(trailingHandle.x.toDouble()).toInt() + 2 * trailingHandle.width

    val leadingOverlayParams = leadingOverlay.layoutParams as RelativeLayout.LayoutParams
    leadingOverlayParams.width = left
    leadingOverlayParams.height = RelativeLayout.LayoutParams.MATCH_PARENT
    leadingOverlayParams.addRule(RelativeLayout.ALIGN_PARENT_START)
    leadingOverlay.layoutParams = leadingOverlayParams

    val trailingOverlayParams = trailingOverlay.layoutParams as RelativeLayout.LayoutParams
    trailingOverlayParams.width = right
    trailingOverlayParams.height = RelativeLayout.LayoutParams.MATCH_PARENT
    trailingOverlayParams.addRule(RelativeLayout.ALIGN_PARENT_END)
    trailingOverlay.layoutParams = trailingOverlayParams
  }

  private fun playHapticFeedback(isLight: Boolean) {
    if (vibrator != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && enableHapticFeedback) {
      vibrator!!.vibrate(VibrationEffect.createOneShot(if (isLight) 10L else 25L, VibrationEffect.DEFAULT_AMPLITUDE))
    }
  }

  private fun startZoomWaitTimer() {
    stopZoomWaitTimer()
    if (isZoomedIn) return

    zoomRunnable = Runnable {
      stopZoomWaitTimer()
      zoomIfNeeded()
    }

    zoomWaitTimer.postDelayed(zoomRunnable!!, 500)
  }

  private fun stopZoomWaitTimer() {
    zoomRunnable?.let { zoomWaitTimer.removeCallbacks(it) }
  }

  private fun stopZoomIfNeeded() {
    stopZoomWaitTimer()
    if (isZoomedIn) {
      isGeneratingThumbnails = false
      BackgroundExecutor.cancelAll("progressive_thumbs", true)
      isZoomedIn = false
      restoreCachedThumbnails()
      animateZoomTransition {
        updateHandlePositions()
        updateCurrentTime(true)
      }
    }
  }

  private fun zoomIfNeeded() {
    if (isZoomedIn) return

    val currentLeadingX = leadingHandle.x
    val currentTrailingX = trailingHandle.x

    var newDuration = minOf(zoomOnWaitingDuration, mDuration.toLong())

    when {
      mDuration < 2000 -> newDuration = maxOf(500L, mDuration.toLong() / 2)
      mDuration < zoomOnWaitingDuration -> newDuration = maxOf(1000L, mDuration.toLong() / 2)
    }

    newDuration = minOf(newDuration, mDuration.toLong())

    val rangeStart = if (isTrimmingLeading) {
      var rs = maxOf(0L, startTime - newDuration / 2)
      if (rs + newDuration > mDuration) rs = maxOf(0L, mDuration.toLong() - newDuration)
      rs
    } else {
      var rs = maxOf(0L, endTime - newDuration / 2)
      if (rs + newDuration > mDuration) rs = maxOf(0L, mDuration.toLong() - newDuration)
      rs
    }

    zoomedInRangeStart = maxOf(0L, rangeStart)
    zoomedInRangeDuration = minOf(newDuration, mDuration.toLong() - zoomedInRangeStart)

    isZoomedIn = true

    startProgressiveThumbnailGeneration()
    updateHandlePositionsForZoom(currentLeadingX, currentTrailingX)
    playHapticFeedback(true)
  }

  private fun updateHandlePositionsForZoom(previousLeadingX: Float, previousTrailingX: Float) {
    Log.d(TAG, "Maintaining handle positions during zoom - Leading: $previousLeadingX, Trailing: $previousTrailingX")

    leadingHandle.x = previousLeadingX
    trailingHandle.x = previousTrailingX

    updateTrimmerContainerWidth()

    val leftBoundary = leadingHandle.x + leadingHandle.width
    val rightBoundary = trailingHandle.x - progressIndicator.width
    val currentX = progressIndicator.x

    if (currentX < leftBoundary || currentX > rightBoundary) {
      updateCurrentTime(true)
    } else {
      updateCurrentTime(false)
    }

    trimmerContainerWrapper.visibility = View.VISIBLE
    if (trimmerContainerWrapper.alpha == 0f) {
      trimmerContainerWrapper.animate().alpha(1f).setDuration(250).start()
    }
  }

  private fun startProgressiveThumbnailGeneration() {
    if (isGeneratingThumbnails || mediaMetadataRetriever == null) return

    isGeneratingThumbnails = true

    UiThreadExecutor.runTask("", {
      mThumbnailContainer.removeAllViews()

      val containerContentWidth = mThumbnailContainer.width - mThumbnailContainer.paddingLeft - mThumbnailContainer.paddingRight
      val effectiveWidth = if (containerContentWidth > 0) containerContentWidth else VideoTrimmerUtil.VIDEO_FRAMES_WIDTH
      val thumbWidth = VideoTrimmerUtil.VIDEO_FRAMES_WIDTH / VideoTrimmerUtil.MAX_COUNT_RANGE
      val numberOfThumbnails = maxOf(8, effectiveWidth / maxOf(1, thumbWidth))
      val baseWidth = effectiveWidth / numberOfThumbnails
      val remainder = effectiveWidth % numberOfThumbnails

      for (i in 0 until numberOfThumbnails) {
        val placeholder = ImageView(context)
        val width = if (i < remainder) baseWidth + 1 else baseWidth
        val layoutParams = LinearLayout.LayoutParams(width, LinearLayout.LayoutParams.MATCH_PARENT)
        placeholder.layoutParams = layoutParams
        placeholder.setBackgroundColor("#F0F0F0".toColorInt())
        placeholder.alpha = 0.2f
        mThumbnailContainer.addView(placeholder)
      }
    }, 0)

    BackgroundExecutor.execute(object : BackgroundExecutor.Task("progressive_thumbs", 0L, "") {
      override fun execute() {
        try {
          val thumbnailWidth = VideoTrimmerUtil.VIDEO_FRAMES_WIDTH / VideoTrimmerUtil.MAX_COUNT_RANGE
          val numberOfThumbnails = maxOf(8, mThumbnailContainer.width / thumbnailWidth)
          val visibleDuration = if (isZoomedIn) zoomedInRangeDuration else mDuration.toLong()
          val visibleStart = if (isZoomedIn) zoomedInRangeStart else 0L
          val interval = if (visibleDuration > 0) visibleDuration / numberOfThumbnails else 0L

          for (i in 0 until numberOfThumbnails) {
            if (!isGeneratingThumbnails || !isZoomedIn) {
              Log.d(TAG, "Thumbnail generation cancelled at index $i")
              return
            }

            val index = i
            val timeUs = (visibleStart + i * interval) * 1000
            val clampedTimeUs = maxOf(0L, minOf(timeUs, mDuration * 1000L))

            try {
              val bitmap = synchronized(retrieverLock) {
                if (retrieverReleased) null else mediaMetadataRetriever?.getFrameAtTime(clampedTimeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
              }
              if (bitmap != null && isGeneratingThumbnails && isZoomedIn) {
                UiThreadExecutor.runTask("", {
                  if (isZoomedIn && index < mThumbnailContainer.childCount) {
                    val thumbnailView = mThumbnailContainer.getChildAt(index) as? ImageView
                    if (thumbnailView != null) {
                      thumbnailView.setImageBitmap(bitmap)
                      thumbnailView.scaleType = ImageView.ScaleType.CENTER_CROP
                      thumbnailView.background = null

                      thumbnailView.animate()
                        .alpha(1.0f)
                        .setDuration(150)
                        .setStartDelay(index * 50L)
                        .start()
                    }
                  }
                }, 0)

                Thread.sleep(10)
              }
            } catch (e: Exception) {
              Log.w(TAG, "Error generating progressive thumbnail at $clampedTimeUs", e)
            }
          }

          isGeneratingThumbnails = false
        } catch (e: Exception) {
          Log.e(TAG, "Error in progressive thumbnail generation", e)
          isGeneratingThumbnails = false
        }
      }
    })
  }

  private fun animateZoomTransition(onComplete: Runnable?) {
    mThumbnailContainer.animate()
      .alpha(0.7f)
      .setDuration(200)
      .withEndAction {
        onComplete?.run()
        mThumbnailContainer.animate()
          .alpha(1.0f)
          .setDuration(200)
          .start()
      }
      .start()
  }

  private fun ignoreSystemGestureForView(v: View) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      v.systemGestureExclusionRects = listOf(
        android.graphics.Rect(0, 0, DeviceUtil.getDeviceWidth(), DeviceUtil.getDeviceHeight())
      )
    }
  }

  private fun timeForPosition(position: Float): Long {
    if (trimmerContainerBg.width <= 0) return 0

    return if (isZoomedIn) {
      val ratio = position / trimmerContainerBg.width
      zoomedInRangeStart + (ratio * zoomedInRangeDuration).toLong()
    } else {
      (position / trimmerContainerBg.width * mDuration).toLong()
    }
  }

  private fun positionForTime(time: Long): Float {
    return if (isZoomedIn) {
      if (zoomedInRangeDuration <= 0) return 0f
      val ratio = (time - zoomedInRangeStart).toFloat() / zoomedInRangeDuration
      maxOf(0f, minOf(trimmerContainerBg.width.toFloat(), ratio * trimmerContainerBg.width))
    } else {
      if (mDuration <= 0) return 0f
      maxOf(0f, minOf(trimmerContainerBg.width.toFloat(), time.toFloat() / mDuration * trimmerContainerBg.width))
    }
  }

  private fun getVisibleRangeStart(): Long {
    return if (isZoomedIn) zoomedInRangeStart else 0
  }

  private fun getVisibleRangeDuration(): Long {
    return if (isZoomedIn) zoomedInRangeDuration else mDuration.toLong()
  }

  private fun restoreCachedThumbnails() {
    mThumbnailContainer.removeAllViews()

    for (cachedThumbnail in cachedFullViewThumbnails) {
      val restoredView = ImageView(context)
      restoredView.setImageBitmap((cachedThumbnail.drawable as android.graphics.drawable.BitmapDrawable).bitmap)
      restoredView.scaleType = ImageView.ScaleType.CENTER_CROP
      restoredView.layoutParams = cachedThumbnail.layoutParams
      mThumbnailContainer.addView(restoredView)
    }
  }

  // region Transform

  private fun containerContentWidth(): Float =
    (videoContainer.width - videoContainer.paddingLeft - videoContainer.paddingRight).toFloat()

  private fun containerContentHeight(): Float =
    (videoContainer.height - videoContainer.paddingTop - videoContainer.paddingBottom).toFloat()

  private fun bracketOverflow(): Int =
    TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 4f, resources.displayMetrics).toInt()

  private fun onFlipTapped() {
    pushUndo()
    isFlipped = !isFlipped
    val newCumDeg = -cumulativeRotationDeg
    val fitScale = if (rotationCount % 2 != 0) {
      val cw = containerContentWidth()
      val ch = containerContentHeight()
      if (cw > 0 && ch > 0) minOf(cw / ch, ch / cw) else 1f
    } else {
      1f
    }
    val targetSx = (if (isFlipped) -1f else 1f) * fitScale
    val oddRotation = rotationCount % 2 != 0

    mVideoView.animate().cancel()
    if (oddRotation) {
      mVideoView.animate()
        .scaleY(0f)
        .setDuration(125)
        .setInterpolator(DecelerateInterpolator())
        .withEndAction {
          cumulativeRotationDeg = newCumDeg
          mVideoView.rotation = newCumDeg
          mVideoView.scaleX = targetSx
          mVideoView.animate()
            .scaleY(fitScale)
            .setDuration(125)
            .setInterpolator(DecelerateInterpolator())
            .withEndAction {
              if (isCropActive) {
                updateCropAllowedRect()
                cropOverlay?.resetCrop()
              }
            }
            .start()
        }
        .start()
    } else {
      mVideoView.animate()
        .scaleX(0f)
        .setDuration(125)
        .setInterpolator(DecelerateInterpolator())
        .withEndAction {
          cumulativeRotationDeg = newCumDeg
          mVideoView.rotation = newCumDeg
          mVideoView.animate()
            .scaleX(targetSx)
            .setDuration(125)
            .setInterpolator(DecelerateInterpolator())
            .withEndAction {
              if (isCropActive) {
                updateCropAllowedRect()
                cropOverlay?.resetCrop()
              }
            }
            .start()
        }
        .start()
    }
    playHapticFeedback(true)
  }

  private fun onRotateTapped() {
    pushUndo()
    if (isFlipped) {
      rotationCount = (rotationCount - 1 + 4) % 4
    } else {
      rotationCount = (rotationCount + 1) % 4
    }
    cumulativeRotationDeg -= 90f
    updateVideoTransform(resetCrop = true)
    playHapticFeedback(true)
  }

  private fun updateVideoTransform(resetCrop: Boolean = false) {
    val cw = containerContentWidth()
    val ch = containerContentHeight()
    if (cw <= 0 || ch <= 0) return

    val fitScale = if (rotationCount % 2 != 0) {
      minOf(cw / ch, ch / cw)
    } else {
      1f
    }
    val flipMul = if (isFlipped) -1f else 1f

    mVideoView.animate()
      .scaleX(flipMul * fitScale)
      .scaleY(fitScale)
      .rotation(cumulativeRotationDeg)
      .setDuration(250)
      .setInterpolator(DecelerateInterpolator())
      .withEndAction {
        if (resetCrop && isCropActive) {
          updateCropAllowedRect()
          cropOverlay?.resetCrop()
        }
      }
      .start()
  }

  // endregion

  // region Crop

  private fun onCropTapped() {
    isCropActive = !isCropActive
    cropBtn.setColorFilter(
      if (isCropActive) Color.WHITE else Color.argb(128, 255, 255, 255),
      android.graphics.PorterDuff.Mode.SRC_IN
    )
    playHapticFeedback(true)
    if (isCropActive) showCropOverlay() else hideCropOverlay()
  }

  private fun showCropOverlay() {
    hideCropOverlayImmediate()
    val overlay = CropOverlayView(mContext)
    overlay.layoutParams = FrameLayout.LayoutParams(
      FrameLayout.LayoutParams.MATCH_PARENT,
      FrameLayout.LayoutParams.MATCH_PARENT
    )
    overlay.alpha = 0f
    overlay.onCropBegan = { preCropSnapshot = currentSnapshot() }
    overlay.onCropEnded = {
      val before = preCropSnapshot
      preCropSnapshot = null
      if (before != null && before != currentSnapshot()) {
        undoStack.add(before)
        redoStack.clear()
        updateUndoRedoButtons()
      }
    }
    videoContainer.addView(overlay)
    cropOverlay = overlay
    videoContainer.post {
      updateCropAllowedRect()
      overlay.resetCrop()
      overlay.animate().alpha(1f).setDuration(200).start()
    }
  }

  private fun hideCropOverlay() {
    val overlay = cropOverlay ?: return
    overlay.animate().alpha(0f).setDuration(200).withEndAction {
      videoContainer.removeView(overlay)
    }.start()
    cropOverlay = null
  }

  private fun showCropOverlayImmediate() {
    hideCropOverlayImmediate()
    val overlay = CropOverlayView(mContext)
    overlay.layoutParams = FrameLayout.LayoutParams(
      FrameLayout.LayoutParams.MATCH_PARENT,
      FrameLayout.LayoutParams.MATCH_PARENT
    )
    overlay.onCropBegan = { preCropSnapshot = currentSnapshot() }
    overlay.onCropEnded = {
      val before = preCropSnapshot
      preCropSnapshot = null
      if (before != null && before != currentSnapshot()) {
        undoStack.add(before)
        redoStack.clear()
        updateUndoRedoButtons()
      }
    }
    videoContainer.addView(overlay)
    cropOverlay = overlay
    updateCropAllowedRect()
  }

  private fun hideCropOverlayImmediate() {
    val overlay = cropOverlay ?: return
    videoContainer.removeView(overlay)
    cropOverlay = null
  }

  private fun updateCropAllowedRect() {
    cropOverlay?.allowedRect = getVideoDisplayRectInContainer()
  }

  private fun getVideoDisplayRectInContainer(): RectF {
    val cw = containerContentWidth()
    val ch = containerContentHeight()
    if (cw <= 0 || ch <= 0) return RectF()

    val tvW = mVideoView.width.toFloat()
    val tvH = mVideoView.height.toFloat()
    if (tvW <= 0 || tvH <= 0) return RectF()

    val tvX = (cw - tvW) / 2f
    val tvY = (ch - tvH) / 2f
    val videoRect = RectF(tvX, tvY, tvX + tvW, tvY + tvH)

    val pivotX = cw / 2f
    val pivotY = ch / 2f
    val fitScale = if (rotationCount % 2 != 0) {
      minOf(cw / ch, ch / cw)
    } else {
      1f
    }
    val flipMul = if (isFlipped) -1f else 1f
    val geoRotation = if (isFlipped) rotationCount * 90f else -rotationCount * 90f
    val matrix = Matrix()
    matrix.setScale(flipMul * fitScale, fitScale, pivotX, pivotY)
    matrix.postRotate(geoRotation, pivotX, pivotY)

    val pts = floatArrayOf(
      videoRect.left, videoRect.top,
      videoRect.right, videoRect.top,
      videoRect.right, videoRect.bottom,
      videoRect.left, videoRect.bottom
    )
    matrix.mapPoints(pts)

    var minX = pts[0]; var minY = pts[1]
    var maxX = pts[0]; var maxY = pts[1]
    for (i in 1 until 4) {
      minX = minOf(minX, pts[i * 2])
      minY = minOf(minY, pts[i * 2 + 1])
      maxX = maxOf(maxX, pts[i * 2])
      maxY = maxOf(maxY, pts[i * 2 + 1])
    }
    return RectF(minX, minY, maxX, maxY)
  }

  fun getCropNormalizedRect(): RectF? {
    if (!isCropActive) return null
    val overlay = cropOverlay ?: return null
    val cr = overlay.cropRect
    val allowed = overlay.allowedRect
    if (cr.isEmpty || allowed.isEmpty) return null
    if (allowed.width() <= 0 || allowed.height() <= 0) return null

    val normX = (cr.left - allowed.left) / allowed.width()
    val normY = (cr.top - allowed.top) / allowed.height()
    val normW = cr.width() / allowed.width()
    val normH = cr.height() / allowed.height()

    if (normX < 0.01f && normY < 0.01f && normW > 0.98f && normH > 0.98f) return null
    return RectF(normX, normY, normX + normW, normY + normH)
  }

  private fun setCropFromNormalized(norm: RectF) {
    val overlay = cropOverlay ?: return
    val allowed = overlay.allowedRect
    if (allowed.isEmpty) return
    val x = allowed.left + norm.left * allowed.width()
    val y = allowed.top + norm.top * allowed.height()
    val w = norm.width() * allowed.width()
    val h = norm.height() * allowed.height()
    overlay.cropRect = RectF(x, y, x + w, y + h)
  }

  // endregion

  // region Undo / Redo

  private fun currentSnapshot(): TransformSnapshot {
    return TransformSnapshot(
      rotationCount = rotationCount,
      isFlipped = isFlipped,
      isCropActive = isCropActive,
      cropNormalized = getCropNormalizedRect(),
      cumulativeRotationDeg = cumulativeRotationDeg
    )
  }

  private fun pushUndo() {
    undoStack.add(currentSnapshot())
    redoStack.clear()
    updateUndoRedoButtons()
  }

  private fun onUndoTapped() {
    if (undoStack.isEmpty()) return
    redoStack.add(currentSnapshot())
    val snap = undoStack.removeLast()
    applySnapshot(snap)
    updateUndoRedoButtons()
  }

  private fun onRedoTapped() {
    if (redoStack.isEmpty()) return
    undoStack.add(currentSnapshot())
    val snap = redoStack.removeLast()
    applySnapshot(snap)
    updateUndoRedoButtons()
  }

  private fun applySnapshot(snap: TransformSnapshot) {
    val flipChanging = isFlipped != snap.isFlipped
    val prevRotationCount = rotationCount

    rotationCount = snap.rotationCount
    isFlipped = snap.isFlipped
    cumulativeRotationDeg = snap.cumulativeRotationDeg

    val cw = containerContentWidth()
    val ch = containerContentHeight()
    val fitScale = if (rotationCount % 2 != 0 && cw > 0 && ch > 0) {
      minOf(cw / ch, ch / cw)
    } else {
      1f
    }
    val flipMul = if (isFlipped) -1f else 1f
    val targetSx = flipMul * fitScale

    val onComplete = Runnable {
      if (snap.isCropActive) {
        isCropActive = true
        cropBtn.setColorFilter(Color.WHITE, android.graphics.PorterDuff.Mode.SRC_IN)
        showCropOverlayImmediate()
        updateCropAllowedRect()
        val norm = snap.cropNormalized
        if (norm != null) setCropFromNormalized(norm) else cropOverlay?.resetCrop()
      } else {
        isCropActive = false
        cropBtn.setColorFilter(
          Color.argb(128, 255, 255, 255),
          android.graphics.PorterDuff.Mode.SRC_IN
        )
        hideCropOverlayImmediate()
      }
    }

    mVideoView.animate().cancel()

    if (flipChanging) {
      val oddRotation = prevRotationCount % 2 != 0
      if (oddRotation) {
        mVideoView.animate()
          .scaleY(0f)
          .setDuration(125)
          .setInterpolator(DecelerateInterpolator())
          .withEndAction {
            mVideoView.rotation = cumulativeRotationDeg
            mVideoView.scaleX = targetSx
            mVideoView.animate()
              .scaleY(fitScale)
              .setDuration(125)
              .setInterpolator(DecelerateInterpolator())
              .withEndAction { onComplete.run() }
              .start()
          }
          .start()
      } else {
        mVideoView.animate()
          .scaleX(0f)
          .setDuration(125)
          .setInterpolator(DecelerateInterpolator())
          .withEndAction {
            mVideoView.rotation = cumulativeRotationDeg
            mVideoView.animate()
              .scaleX(targetSx)
              .setDuration(125)
              .setInterpolator(DecelerateInterpolator())
              .withEndAction { onComplete.run() }
              .start()
          }
          .start()
      }
    } else {
      mVideoView.animate()
        .scaleX(targetSx)
        .scaleY(fitScale)
        .rotation(cumulativeRotationDeg)
        .setDuration(250)
        .setInterpolator(DecelerateInterpolator())
        .withEndAction { onComplete.run() }
        .start()
    }
  }

  private fun updateUndoRedoButtons() {
    val dimmed = Color.argb(128, 255, 255, 255)
    val active = Color.WHITE
    undoBtn.isEnabled = undoStack.isNotEmpty()
    undoBtn.setColorFilter(
      if (undoStack.isNotEmpty()) active else dimmed,
      android.graphics.PorterDuff.Mode.SRC_IN
    )
    redoBtn.isEnabled = redoStack.isNotEmpty()
    redoBtn.setColorFilter(
      if (redoStack.isNotEmpty()) active else dimmed,
      android.graphics.PorterDuff.Mode.SRC_IN
    )
  }

  // endregion
}
