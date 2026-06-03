package com.videotrim.widgets

import android.content.Context
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.RectF
import android.graphics.SurfaceTexture
import android.graphics.drawable.GradientDrawable
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.media.PlaybackParams
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

  // region Audio waveform state
  //
  // For audio files the trimmer replaces the thumbnail track with a waveform.
  // Amplitudes are extracted via MediaExtractor + MediaCodec (hardware-accelerated
  // PCM decode) and rendered by AudioWaveformView as rounded-rect bars.
  //
  // Remote files are first downloaded to a local cache file so that both the
  // initial extraction and any zoom-level re-extractions can read from disk
  // instead of re-streaming over the network each time.
  private var waveformView: AudioWaveformView? = null
  /** Full-view (non-zoomed) amplitudes, cached so we can restore instantly on zoom-out. */
  private var cachedFullWaveformAmplitudes: FloatArray? = null
  @Volatile
  private var isGeneratingWaveform = false
  /** Local file path used for waveform extraction (populated after downloading remote audio). */
  private var localAudioFilePath: String? = null
  @Volatile
  private var isDownloadingAudio = false
  private var waveformBarColor = Color.WHITE
  private var waveformBgColor = Color.parseColor("#3478F6")
  private var waveformBarWidthDp = 3f
  private var waveformBarGapDp = 2f
  private var waveformBarCornerRadiusDp = 1.5f
  // endregion

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
  private var enableEditTools = true
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
  private lateinit var muteBtn: ImageView
  private lateinit var speedBtn: TextView
  private lateinit var videoContainer: FrameLayout
  private var cropOverlay: CropOverlayView? = null

  internal var isMuted = false
    private set
  private var configRemoveAudio = false
  private var speed: Double = 1.0
  private val speedOptions = doubleArrayOf(0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0)

  private lateinit var trimmerView: RelativeLayout

  private var trimmerColor = context.getString(R.string.trim_color).toColorInt()
  private var handleIconColor = Color.BLACK
  private var isLightTheme = false
  private var durationFormat: String = "mm:ss.SSS"
  private val iconColor: Int get() = if (isLightTheme) Color.BLACK else Color.WHITE
  private val dimmedIconColor: Int get() = if (isLightTheme) Color.argb(128, 0, 0, 0) else Color.argb(128, 255, 255, 255)
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
    muteBtn = findViewById(R.id.muteBtn)
    speedBtn = findViewById(R.id.speedBtn)
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
          val mp = mediaPlayer
          if (mp != null) {
            videoSurface?.release()
            videoSurface = Surface(st)
            mp.setSurface(videoSurface)
          } else {
            setupVideoPlayer(st, videoURI)
          }
        }
        override fun onSurfaceTextureSizeChanged(st: SurfaceTexture, w: Int, h: Int) {}
        override fun onSurfaceTextureDestroyed(st: SurfaceTexture): Boolean {
          return false
        }
        override fun onSurfaceTextureUpdated(st: SurfaceTexture) {}
      }
    } else {
      // Audio path: hide video surface, show the audio banner with a fade-in,
      // and kick off waveform generation *in parallel* with MediaPlayer.prepareAsync()
      // so the waveform starts appearing as soon as possible (the download / decode
      // runs on a background thread while MediaPlayer streams independently).
      mVideoView.visibility = View.GONE
      audioBannerView.alpha = 0f
      audioBannerView.visibility = View.VISIBLE
      audioBannerView.animate().alpha(1f).setDuration(500).start()

      VideoTrimmerUtil.SCREEN_WIDTH_FULL = getScreenWidthInPortraitMode()
      VideoTrimmerUtil.VIDEO_FRAMES_WIDTH = VideoTrimmerUtil.SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2
      // endMs = 0 means "unknown duration"; extractAmplitudes will fall back
      // to the track's KEY_DURATION or a sensible default.
      startWaveformGeneration(0, 0)

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

    if (!isVideoType) {
      // Waveform generation was started in initByURI, but the view is only
      // created here (after MediaPlayer is ready) so the background color
      // doesn't flash before the trimmer container is visible.
      VideoTrimmerUtil.SCREEN_WIDTH_FULL = getScreenWidthInPortraitMode()
      VideoTrimmerUtil.VIDEO_FRAMES_WIDTH = VideoTrimmerUtil.SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2
      if (waveformView == null) {
        setupWaveformView()
      }
      // If the background generation already finished, apply cached data immediately.
      cachedFullWaveformAmplitudes?.let { waveformView?.setAmplitudes(it) }
      // If generation hasn't started yet (e.g. failed the first time), retry
      // now that we know the actual duration.
      if (!isGeneratingWaveform && cachedFullWaveformAmplitudes == null) {
        startWaveformGeneration(0, mDuration.toLong())
      }
    }

    endTime = if (mMaxDuration < mDuration) mMaxDuration else mDuration.toLong()
    updateHandlePositions()

    loadingIndicator.visibility = View.GONE
    mPlayView.visibility = View.VISIBLE
    saveBtn.visibility = View.VISIBLE

    if (jumpToPositionOnLoad > 0) {
      // Clamp to endTime so that jumpToPositionOnLoad > maxDuration doesn't
      // cause an immediate pause (the old bug where autoplay appeared broken).
      val clampedJump = jumpToPositionOnLoad.coerceAtMost(endTime)
      seekTo(if (clampedJump > mDuration) mDuration.toLong() else clampedJump, true)
    }

    if (autoplay) {
      playOrPause()
    }

    mediaPlayer?.setVolume(if (isMuted) 0f else 1f, if (isMuted) 0f else 1f)
    // Do NOT call applyPlaybackSpeed() here. On Android, MediaPlayer.setPlaybackParams()
    // with non-zero speed on a prepared player is equivalent to start(), which would
    // silently begin playback even when autoplay=false. The configured speed is applied
    // by playOrPause() after the explicit start() call instead.

    if (isVideoType) {
      if (enableEditTools) {
        transformRow.alpha = 0f
        transformRow.visibility = View.VISIBLE
        transformRow.animate().alpha(1f).setDuration(250).start()
        updateUndoRedoButtons()
      } else {
        // Hide the entire top toolbar (flip/rotate/crop/mute/speed/undo/redo).
        // The layout already defaults transformRow to gone, but set it explicitly
        // in case the value changed across editor sessions.
        transformRow.visibility = View.GONE
      }
    } else {
      // Fade the waveform in to match the trimmer container animation.
      waveformView?.animate()?.alpha(1f)?.setDuration(250)?.start()
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
      applyPlaybackSpeed()
      startTimingRunnable()
    }
    setPlayPauseViewIcon(player.isPlaying)
  }

  private fun applyPlaybackSpeed() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      val player = mediaPlayer ?: return
      val params = player.playbackParams ?: PlaybackParams()
      player.playbackParams = params.setSpeed(speed.toFloat())
    }
  }

  private fun onMuteTapped() {
    isMuted = !isMuted
    muteBtn.setImageResource(if (isMuted) R.drawable.speaker_slash_fill else R.drawable.speaker_wave_2_fill)
    mediaPlayer?.setVolume(if (isMuted) 0f else 1f, if (isMuted) 0f else 1f)
    if (enableHapticFeedback) {
      performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
    }
  }

  // Uses Android's native PopupMenu anchored to the speed button for a platform-
  // consistent speed selector (equivalent to iOS's UIMenu on iOS 14+).
  private fun onSpeedTapped() {
    val popup = android.widget.PopupMenu(context, speedBtn)
    speedOptions.forEachIndexed { index, opt ->
      val title = if (opt == 1.0) "Normal (1x)" else "${opt}x"
      popup.menu.add(0, index, index, title)
    }
    popup.setOnMenuItemClickListener { item ->
      setSpeed(speedOptions[item.itemId])
      true
    }
    popup.show()
  }

  private fun setSpeed(newSpeed: Double) {
    speed = newSpeed
    speedBtn.text = if (newSpeed == 1.0) "1x" else "${newSpeed}x"
    // Only apply playbackParams when actively playing. Calling setPlaybackParams() on a
    // prepared-but-paused MediaPlayer implicitly starts playback (Android docs), which
    // would silently resume the video when the user just wanted to pick a future speed.
    // When paused, the new speed is picked up by playOrPause() on the next play.
    val player = mediaPlayer
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && player != null && player.isPlaying) {
      player.playbackParams = player.playbackParams.setSpeed(newSpeed.toFloat())
    }
    if (enableHapticFeedback) {
      performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
    }
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
    muteBtn.setOnClickListener { onMuteTapped() }
    speedBtn.setOnClickListener { onSpeedTapped() }

    cropBtn.setColorFilter(dimmedIconColor, android.graphics.PorterDuff.Mode.SRC_IN)
    undoBtn.setColorFilter(dimmedIconColor, android.graphics.PorterDuff.Mode.SRC_IN)
    redoBtn.setColorFilter(dimmedIconColor, android.graphics.PorterDuff.Mode.SRC_IN)
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
    val effectiveRemoveAudio = isMuted || configRemoveAudio
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
      effectiveRemoveAudio,
      speed,
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

  /**
   * Comprehensive cleanup when the editor is dismissed.
   *
   * The user can close the editor at any time — even immediately after opening —
   * so every background task and media resource must be released here:
   *  • Flags (isGeneratingThumbnails / isGeneratingWaveform) are set to false first
   *    so that in-flight background loops exit early on the next iteration.
   *  • Named BackgroundExecutor tasks are cancelled to interrupt pending work.
   *  • MediaPlayer listeners are nulled *before* stop()/release() to prevent
   *    callbacks firing on a half-torn-down view.
   *  • The downloaded local audio cache file is deleted.
   *  • SurfaceTexture listener is cleared to avoid stale references.
   */
  override fun onDestroy() {
    isGeneratingThumbnails = false
    isGeneratingWaveform = false
    BackgroundExecutor.cancelAll("initial_thumbs", true)
    BackgroundExecutor.cancelAll("progressive_thumbs", true)
    BackgroundExecutor.cancelAll("waveform_gen", true)
    UiThreadExecutor.cancelAll("")
    mContext.currentActivity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
    mTimingRunnable?.let { mTimingHandler.removeCallbacks(it) }
    zoomRunnable?.let { zoomWaitTimer.removeCallbacks(it) }

    cachedFullViewThumbnails.clear()
    cachedFullWaveformAmplitudes = null
    waveformView = null
    cleanupLocalAudioFile()

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
      mediaMetadataRetriever = null
    }

    try {
      mediaPlayer?.setOnPreparedListener(null)
      mediaPlayer?.setOnCompletionListener(null)
      mediaPlayer?.setOnErrorListener(null)
      mediaPlayer?.stop()
      mediaPlayer?.release()
    } catch (e: IllegalStateException) {
      e.printStackTrace()
      Log.d(TAG, "onDestroy mediaPlayer is already released")
    }
    mediaPlayer = null

    try {
      mVideoView.surfaceTextureListener = null
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

    isLightTheme = config.hasKey("theme") && config.getString("theme") == "light"
    durationFormat = if (config.hasKey("durationFormat")) config.getString("durationFormat") ?: "mm:ss.SSS" else "mm:ss.SSS"

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
    enableEditTools = if (config.hasKey("enableEditTools")) config.getBoolean("enableEditTools") else true
    autoplay = config.hasKey("autoplay") && config.getBoolean("autoplay")

    if (config.hasKey("removeAudio")) {
      configRemoveAudio = config.getBoolean("removeAudio")
      isMuted = configRemoveAudio
    }
    if (config.hasKey("speed") && config.getDouble("speed") > 0) {
      speed = config.getDouble("speed")
      speedBtn.text = if (speed == 1.0) "1x" else "${speed}x"
    }
    muteBtn.setImageResource(if (isMuted) R.drawable.speaker_slash_fill else R.drawable.speaker_wave_2_fill)
    muteBtn.visibility = if (isVideoType) View.VISIBLE else View.GONE

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
    handleIconColor = if (config.hasKey("handleIconColor")) config.getInt("handleIconColor") else (if (isLightTheme) Color.WHITE else Color.BLACK)

    if (config.hasKey("waveformColor")) {
      waveformBarColor = config.getInt("waveformColor")
    }
    if (config.hasKey("waveformBackgroundColor")) {
      waveformBgColor = config.getInt("waveformBackgroundColor")
    }
    if (config.hasKey("waveformBarWidth") && config.getDouble("waveformBarWidth") > 0) {
      waveformBarWidthDp = config.getDouble("waveformBarWidth").toFloat()
    }
    if (config.hasKey("waveformBarGap") && config.getDouble("waveformBarGap") >= 0) {
      waveformBarGapDp = config.getDouble("waveformBarGap").toFloat()
    }
    if (config.hasKey("waveformBarCornerRadius") && config.getDouble("waveformBarCornerRadius") >= 0) {
      waveformBarCornerRadiusDp = config.getDouble("waveformBarCornerRadius").toFloat()
    }

    applyTrimmerColor()
    applyThemeColors()
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

  private fun applyThemeColors() {
    val bgColor = if (isLightTheme) Color.WHITE else Color.BLACK
    val textColor = if (isLightTheme) Color.BLACK else Color.WHITE
    val overlayColor = if (isLightTheme) Color.argb(153, 255, 255, 255) else Color.argb(191, 0, 0, 0)

    // Backgrounds
    (findViewById<View>(R.id.layout) as? RelativeLayout)?.setBackgroundColor(bgColor)
    headerView.setBackgroundColor(bgColor)
    transformRow.setBackgroundColor(bgColor)
    videoContainer.setBackgroundColor(bgColor)

    // Text colors
    cancelBtn.setTextColor(iconColor)
    startTimeText.setTextColor(textColor)
    currentTimeText.setTextColor(textColor)
    endTimeText.setTextColor(textColor)

    // Play icon
    mPlayView.setColorFilter(iconColor, android.graphics.PorterDuff.Mode.SRC_IN)

    // Transform toolbar icons
    flipBtn.setColorFilter(iconColor, android.graphics.PorterDuff.Mode.SRC_IN)
    rotateBtn.setColorFilter(iconColor, android.graphics.PorterDuff.Mode.SRC_IN)
    cropBtn.setColorFilter(dimmedIconColor, android.graphics.PorterDuff.Mode.SRC_IN)
    undoBtn.setColorFilter(dimmedIconColor, android.graphics.PorterDuff.Mode.SRC_IN)
    redoBtn.setColorFilter(dimmedIconColor, android.graphics.PorterDuff.Mode.SRC_IN)
    muteBtn.setColorFilter(iconColor, android.graphics.PorterDuff.Mode.SRC_IN)
    speedBtn.setTextColor(iconColor)

    // Overlays
    leadingOverlay.setBackgroundColor(overlayColor)
    trailingOverlay.setBackgroundColor(overlayColor)

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
    val totalMs = if (milliseconds < 0) 0 else milliseconds
    val h = totalMs / 3_600_000
    val m = (totalMs / 60_000) % 60
    val s = (totalMs / 1000) % 60
    val ms = totalMs % 1000
    val locale = Locale.getDefault()
    return when (durationFormat) {
      "mm:ss" -> String.format(locale, "%02d:%02d", m + h * 60, s)
      "mm:ss.SS" -> String.format(locale, "%02d:%02d.%02d", m + h * 60, s, ms / 10)
      "hh:mm:ss" -> String.format(locale, "%02d:%02d:%02d", h, m, s)
      "hh:mm:ss.SSS" -> String.format(locale, "%02d:%02d:%02d.%03d", h, m, s, ms)
      else -> String.format(locale, "%02d:%02d.%03d", m + h * 60, s, ms)
    }
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
    var newX = rawXToLocalX(event.rawX)
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
          var newX = rawXToLocalX(event.rawX) - view.width.toFloat() / 2

          if (isLeading) {
            val unclamped = newX
            newX = maxOf(0f, minOf(newX, trailingHandle.x - view.width))
            if (unclamped < 0f) didClamp = true
          } else {
            val unclamped = newX
            val maxX = trimmerContainerBg.width.toFloat() + view.width
            newX = minOf(maxX, maxOf(newX, leadingHandle.x + view.width))
            if (unclamped > maxX) didClamp = true
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
      val amplitude = if (isLight) 30 else 80
      vibrator!!.vibrate(VibrationEffect.createOneShot(if (isLight) 8L else 15L, amplitude))
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
      isGeneratingWaveform = false
      BackgroundExecutor.cancelAll("progressive_thumbs", true)
      BackgroundExecutor.cancelAll("waveform_gen", true)
      isZoomedIn = false
      if (isVideoType) {
        restoreCachedThumbnails()
      } else {
        restoreCachedWaveform()
      }
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

    if (isVideoType) {
      startProgressiveThumbnailGeneration()
    } else {
      if (cachedFullWaveformAmplitudes == null) {
        cachedFullWaveformAmplitudes = waveformView?.amplitudes?.copyOf()
      }
      startProgressiveWaveformGeneration()
    }
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

  /**
   * Convert a screen-absolute X (from [MotionEvent.getRawX]) to a coordinate
   * relative to [trimmerContainerWrapper].
   *
   * Touch events report rawX in screen-space, but the trimmer's handle/indicator
   * positions are in the container's local coordinate space. Without this
   * conversion the playhead lands to the right of the actual finger position.
   */
  private fun rawXToLocalX(rawX: Float): Float {
    val location = IntArray(2)
    trimmerContainerWrapper.getLocationOnScreen(location)
    return rawX - location[0]
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

  // region Waveform — audio-only bar visualization
  //
  // Lifecycle:
  //   1. initByURI starts background download + extraction (startWaveformGeneration).
  //   2. mediaPrepared creates the AudioWaveformView and applies any cached data.
  //   3. On zoom-in the visible time range changes; startProgressiveWaveformGeneration
  //      re-extracts just that sub-range at higher resolution.
  //   4. On zoom-out the cached full-view amplitudes are restored instantly.
  //   5. onDestroy cancels all in-flight work and deletes the local cache file.

  /** Create the AudioWaveformView and add it to the thumbnail container.
   *  Starts with alpha=0; faded in later in mediaPrepared(). */
  private fun setupWaveformView() {
    val density = resources.displayMetrics.density
    val view = AudioWaveformView(context)
    view.barColor = waveformBarColor
    view.setBackgroundColor(waveformBgColor)
    view.barWidthPx = waveformBarWidthDp * density
    view.barGapPx = waveformBarGapDp * density
    view.barCornerRadiusPx = waveformBarCornerRadiusDp * density
    view.layoutParams = LinearLayout.LayoutParams(
      LinearLayout.LayoutParams.MATCH_PARENT,
      LinearLayout.LayoutParams.MATCH_PARENT
    )
    view.alpha = 0f
    mThumbnailContainer.removeAllViews()
    mThumbnailContainer.addView(view)
    waveformView = view
  }

  /**
   * Generate waveform amplitudes for the full (non-zoomed) view.
   *
   * Called from initByURI (with endMs=0 meaning unknown) to start work as
   * early as possible, and again from mediaPrepared if the first attempt
   * didn't produce data (e.g. the duration wasn't known yet).
   *
   * For remote URLs the first call triggers [resolveLocalAudioPath], which
   * downloads the audio to a cache file. Subsequent calls (zoom) reuse
   * that cached file for instant re-extraction without network I/O.
   *
   * Progressive updates are sent to the UI via [onProgress] so the user
   * sees bars filling in as they are decoded, rather than waiting for the
   * entire file to finish.
   */
  private fun startWaveformGeneration(startMs: Long, endMs: Long) {
    if (isGeneratingWaveform) return
    isGeneratingWaveform = true

    val sourceUri = mSourceUri?.toString() ?: return
    val density = resources.displayMetrics.density
    val containerWidth = mThumbnailContainer.width - mThumbnailContainer.paddingLeft - mThumbnailContainer.paddingRight
    val effectiveWidth = if (containerWidth > 0) containerWidth else VideoTrimmerUtil.VIDEO_FRAMES_WIDTH
    val step = waveformBarWidthDp * density + waveformBarGapDp * density
    val barCount = maxOf(1, (effectiveWidth / step).toInt())

    BackgroundExecutor.execute(object : BackgroundExecutor.Task("waveform_gen", 0L, "") {
      override fun execute() {
        try {
          val effectiveUri = resolveLocalAudioPath(sourceUri) ?: return

          val amplitudes = extractAmplitudes(effectiveUri, startMs, endMs, barCount) { intermediate ->
            runOnUiThread {
              if (isGeneratingWaveform) waveformView?.setAmplitudes(intermediate)
            }
          }

          if (!isGeneratingWaveform) return

          cachedFullWaveformAmplitudes = amplitudes.copyOf()

          runOnUiThread {
            waveformView?.setAmplitudes(amplitudes)
          }
        } catch (e: Exception) {
          Log.e(TAG, "Error generating waveform", e)
        } finally {
          isGeneratingWaveform = false
        }
      }
    })
  }

  /** Convert accumulated RMS² values to [0, 1] amplitudes normalised against the peak bar. */
  private fun normalizeAmplitudes(sumSquares: DoubleArray, sampleCounts: IntArray, barCount: Int): FloatArray {
    val amplitudes = FloatArray(barCount)
    var maxAmp = 0f
    for (i in 0 until barCount) {
      if (sampleCounts[i] > 0) {
        amplitudes[i] = kotlin.math.sqrt(sumSquares[i] / sampleCounts[i]).toFloat()
        if (amplitudes[i] > maxAmp) maxAmp = amplitudes[i]
      }
    }
    if (maxAmp > 0f) {
      for (i in amplitudes.indices) {
        amplitudes[i] = (amplitudes[i] / maxAmp).coerceIn(0f, 1f)
      }
    }
    return amplitudes
  }

  /**
   * Decode the audio track in [sourceUri] and compute RMS amplitude per bar.
   *
   * Pipeline:
   *   MediaExtractor (demux compressed packets)
   *     → MediaCodec (hardware-decode to 16-bit PCM)
   *       → on-the-fly RMS accumulation into per-bar buckets
   *
   * Each output buffer's presentation timestamp determines which bar bucket
   * receives its samples. The result is normalised so the loudest bar = 1.0.
   *
   * [onProgress] fires periodically so the UI can show bars filling in
   * incrementally. The first update fires after 5 % of bars are filled
   * (firstUpdateThreshold) and subsequent updates every 20 % (regularUpdateInterval).
   *
   * The codec is wrapped in its own try/finally to guarantee release even
   * if an exception occurs mid-decode (e.g. editor closed).
   *
   * @param startMs start of the time range to extract (ms).
   * @param endMs   end of the time range (ms); 0 = use track/fallback duration.
   * @param barCount number of output amplitude bars.
   */
  private fun extractAmplitudes(
    sourceUri: String, startMs: Long, endMs: Long, barCount: Int,
    onProgress: ((FloatArray) -> Unit)? = null
  ): FloatArray {
    val extractor = MediaExtractor()
    try {
      if (sourceUri.startsWith("http://") || sourceUri.startsWith("https://")) {
        extractor.setDataSource(sourceUri, HashMap())
      } else {
        extractor.setDataSource(sourceUri)
      }

      var audioTrackIndex = -1
      var audioFormat: MediaFormat? = null
      for (i in 0 until extractor.trackCount) {
        val format = extractor.getTrackFormat(i)
        val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
        if (mime.startsWith("audio/")) {
          audioTrackIndex = i
          audioFormat = format
          break
        }
      }
      if (audioTrackIndex < 0 || audioFormat == null) return FloatArray(0)

      extractor.selectTrack(audioTrackIndex)
      extractor.seekTo(startMs * 1000, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

      val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: return FloatArray(0)
      val codec = MediaCodec.createDecoderByType(mime)
      try {
        codec.configure(audioFormat, null, null, 0)
        codec.start()

        val startUs = startMs * 1000L
        // containsKey guard for API < 29 compatibility (getLong(key, default) requires API 29)
        val trackDurationUs = if (audioFormat.containsKey(MediaFormat.KEY_DURATION)) audioFormat.getLong(MediaFormat.KEY_DURATION) else 0L
        val endUs = when {
          endMs > 0 -> endMs * 1000L
          trackDurationUs > 0 -> trackDurationUs
          else -> Long.MAX_VALUE
        }
        val totalDurationUs = maxOf(1L, if (endUs == Long.MAX_VALUE) {
          if (trackDurationUs > 0) trackDurationUs - startUs else 60_000_000L
        } else {
          endUs - startUs
        })
        val barDurationUs = totalDurationUs.toDouble() / barCount

        val sumSquares = DoubleArray(barCount)
        val sampleCounts = IntArray(barCount)
        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        val timeoutUs = 10_000L
        var highestFilledBar = -1
        // Show the first partial waveform early (5% of bars) for perceived speed
        val firstUpdateThreshold = maxOf(1, barCount / 20)
        val regularUpdateInterval = maxOf(1, barCount / 5)
        var lastUpdateBar = -1

        while (!outputDone && isGeneratingWaveform) {
          if (!inputDone) {
            val inputIndex = codec.dequeueInputBuffer(timeoutUs)
            if (inputIndex >= 0) {
              val inputBuffer = codec.getInputBuffer(inputIndex) ?: continue
              val sampleSize = extractor.readSampleData(inputBuffer, 0)
              if (sampleSize < 0 || extractor.sampleTime > endUs) {
                codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                inputDone = true
              } else {
                codec.queueInputBuffer(inputIndex, 0, sampleSize, extractor.sampleTime, 0)
                extractor.advance()
              }
            }
          }

          val outputIndex = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
          if (outputIndex >= 0) {
            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
              outputDone = true
            }
            val outputBuffer = codec.getOutputBuffer(outputIndex)
            if (outputBuffer != null && bufferInfo.size > 0) {
              // Map this buffer's timestamp to the corresponding bar bucket
              val bufferTimeUs = bufferInfo.presentationTimeUs - startUs
              val barIndex = (bufferTimeUs / barDurationUs).toInt().coerceIn(0, barCount - 1)

              outputBuffer.position(bufferInfo.offset)
              outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
              // PCM 16-bit: each sample is 2 bytes (Short)
              val shortCount = bufferInfo.size / 2
              for (i in 0 until shortCount) {
                val sample = outputBuffer.short.toFloat() / Short.MAX_VALUE
                sumSquares[barIndex] += (sample * sample).toDouble()
                sampleCounts[barIndex]++
              }

              if (barIndex > highestFilledBar) highestFilledBar = barIndex

              if (onProgress != null) {
                val interval = if (lastUpdateBar < 0) firstUpdateThreshold else regularUpdateInterval
                if (highestFilledBar - maxOf(0, lastUpdateBar) >= interval) {
                  lastUpdateBar = highestFilledBar
                  onProgress(normalizeAmplitudes(sumSquares, sampleCounts, barCount))
                }
              }
            }
            codec.releaseOutputBuffer(outputIndex, false)
          }
        }

        return normalizeAmplitudes(sumSquares, sampleCounts, barCount)
      } finally {
        try { codec.stop() } catch (_: Exception) {}
        codec.release()
      }
    } finally {
      extractor.release()
    }
  }

  /**
   * Re-extract amplitudes for the currently visible (zoomed-in) time range.
   *
   * Uses the already-downloaded local file if available, so this is a pure
   * disk-read + decode operation with no network latency.
   */
  private fun startProgressiveWaveformGeneration() {
    if (isGeneratingWaveform) return
    isGeneratingWaveform = true

    val sourceUri = mSourceUri?.toString() ?: return
    val density = resources.displayMetrics.density
    val containerWidth = mThumbnailContainer.width - mThumbnailContainer.paddingLeft - mThumbnailContainer.paddingRight
    val effectiveWidth = if (containerWidth > 0) containerWidth else VideoTrimmerUtil.VIDEO_FRAMES_WIDTH
    val step = waveformBarWidthDp * density + waveformBarGapDp * density
    val barCount = maxOf(1, (effectiveWidth / step).toInt())

    val visibleStart = if (isZoomedIn) zoomedInRangeStart else 0L
    val visibleEnd = if (isZoomedIn) zoomedInRangeStart + zoomedInRangeDuration else mDuration.toLong()

    BackgroundExecutor.execute(object : BackgroundExecutor.Task("waveform_gen", 0L, "") {
      override fun execute() {
        try {
          val effectiveUri = localAudioFilePath ?: sourceUri

          val amplitudes = extractAmplitudes(effectiveUri, visibleStart, visibleEnd, barCount) { intermediate ->
            runOnUiThread {
              if (isGeneratingWaveform && isZoomedIn) waveformView?.setAmplitudes(intermediate)
            }
          }

          if (!isGeneratingWaveform || !isZoomedIn) return

          runOnUiThread {
            waveformView?.setAmplitudes(amplitudes)
          }
        } catch (e: Exception) {
          Log.e(TAG, "Error generating zoomed waveform", e)
        } finally {
          isGeneratingWaveform = false
        }
      }
    })
  }

  /** Instantly restore the full-view waveform from cache on zoom-out. */
  private fun restoreCachedWaveform() {
    cachedFullWaveformAmplitudes?.let { cached ->
      waveformView?.setAmplitudes(cached)
    }
  }

  /**
   * Ensure the audio source is available as a local file.
   *
   * For local URIs this is a no-op. For remote (http/https) URIs the file
   * is downloaded once to [Context.getCacheDir] and the path is cached in
   * [localAudioFilePath] for all subsequent reads (zoom re-extractions).
   *
   * Uses a `.tmp` extension because Android's MediaExtractor probes file
   * content to determine the codec, unlike iOS's AVURLAsset which relies
   * on the file extension.
   *
   * Returns null if a download is already in progress or if the editor
   * was closed mid-download (checked via [isGeneratingWaveform]).
   */
  private fun resolveLocalAudioPath(sourceUri: String): String? {
    if (!sourceUri.startsWith("http://") && !sourceUri.startsWith("https://")) {
      return sourceUri
    }

    localAudioFilePath?.let { return it }

    if (isDownloadingAudio) return null
    isDownloadingAudio = true

    try {
      val url = java.net.URL(sourceUri)
      val connection = url.openConnection() as java.net.HttpURLConnection
      connection.connectTimeout = 30_000
      connection.readTimeout = 30_000
      connection.instanceFollowRedirects = true
      connection.connect()

      val destFile = java.io.File(context.cacheDir, "waveform_${System.currentTimeMillis()}.tmp")
      connection.inputStream.use { input ->
        java.io.FileOutputStream(destFile).use { output ->
          val buffer = ByteArray(8192)
          var bytesRead: Int
          while (input.read(buffer).also { bytesRead = it } != -1) {
            if (!isGeneratingWaveform) {
              destFile.delete()
              return null
            }
            output.write(buffer, 0, bytesRead)
          }
        }
      }
      connection.disconnect()

      localAudioFilePath = destFile.absolutePath
      return destFile.absolutePath
    } catch (e: Exception) {
      Log.e(TAG, "Failed to download audio for waveform", e)
      return sourceUri
    } finally {
      isDownloadingAudio = false
    }
  }

  /** Delete the temporary local audio file created by [resolveLocalAudioPath]. */
  private fun cleanupLocalAudioFile() {
    localAudioFilePath?.let {
      try { java.io.File(it).delete() } catch (_: Exception) {}
      localAudioFilePath = null
    }
  }

  // endregion

  // region Transform

  private fun containerContentWidth(): Float =
    (videoContainer.width - videoContainer.paddingLeft - videoContainer.paddingRight).toFloat()

  private fun containerContentHeight(): Float =
    (videoContainer.height - videoContainer.paddingTop - videoContainer.paddingBottom).toFloat()

  private fun bracketOverflow(): Int =
    TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, resources.displayMetrics).toInt()

  private fun onFlipTapped() {
    pushUndo()
    isFlipped = !isFlipped
    val newCumDeg = -cumulativeRotationDeg
    val fitScale = if (rotationCount % 2 != 0) {
      val cw = containerContentWidth()
      val ch = containerContentHeight()
      val vw = mVideoView.width.toFloat()
      val vh = mVideoView.height.toFloat()
      val margin = bracketOverflow().toFloat()
      val availW = cw - 2 * margin
      val availH = ch - 2 * margin
      if (availW > 0 && availH > 0 && vw > 0 && vh > 0) minOf(availW / vh, availH / vw) else 1f
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
      val vw = mVideoView.width.toFloat()
      val vh = mVideoView.height.toFloat()
      val margin = bracketOverflow().toFloat()
      val availW = cw - 2 * margin
      val availH = ch - 2 * margin
      if (vw > 0 && vh > 0 && availW > 0 && availH > 0) minOf(availW / vh, availH / vw) else 1f
    } else {
      1f
    }
    val flipMul = if (isFlipped) -1f else 1f

    if (isCropActive) {
      cropOverlay?.animate()
        ?.alpha(0f)
        ?.setDuration(125)
        ?.start()
    }

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
          cropOverlay?.animate()
            ?.alpha(1f)
            ?.setDuration(125)
            ?.start()
        }
      }
      .start()
  }

  // endregion

  // region Crop

  private fun onCropTapped() {
    isCropActive = !isCropActive
    cropBtn.setColorFilter(
      if (isCropActive) iconColor else dimmedIconColor,
      android.graphics.PorterDuff.Mode.SRC_IN
    )
    playHapticFeedback(true)
    if (isCropActive) showCropOverlay() else hideCropOverlay()
  }

  private fun showCropOverlay() {
    hideCropOverlayImmediate()
    val overlay = CropOverlayView(mContext)
    overlay.isLightTheme = isLightTheme
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
    overlay.isLightTheme = isLightTheme
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
    val margin = bracketOverflow().toFloat()
    val availW = cw - 2 * margin
    val availH = ch - 2 * margin
    val fitScale = if (rotationCount % 2 != 0) {
      if (tvW > 0 && tvH > 0 && availW > 0 && availH > 0) minOf(availW / tvH, availH / tvW) else 1f
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
    val snap = undoStack.removeAt(undoStack.lastIndex)
    applySnapshot(snap)
    updateUndoRedoButtons()
  }

  private fun onRedoTapped() {
    if (redoStack.isEmpty()) return
    undoStack.add(currentSnapshot())
    val snap = redoStack.removeAt(redoStack.lastIndex)
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
    val vw = mVideoView.width.toFloat()
    val vh = mVideoView.height.toFloat()
    val margin = bracketOverflow().toFloat()
    val availW = cw - 2 * margin
    val availH = ch - 2 * margin
    val fitScale = if (rotationCount % 2 != 0 && availW > 0 && availH > 0 && vw > 0 && vh > 0) {
      minOf(availW / vh, availH / vw)
    } else {
      1f
    }
    val flipMul = if (isFlipped) -1f else 1f
    val targetSx = flipMul * fitScale

    val onComplete = Runnable {
      if (snap.isCropActive) {
        isCropActive = true
        cropBtn.setColorFilter(iconColor, android.graphics.PorterDuff.Mode.SRC_IN)
        showCropOverlayImmediate()
        updateCropAllowedRect()
        val norm = snap.cropNormalized
        if (norm != null) setCropFromNormalized(norm) else cropOverlay?.resetCrop()
      } else {
        isCropActive = false
        cropBtn.setColorFilter(dimmedIconColor, android.graphics.PorterDuff.Mode.SRC_IN)
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
    undoBtn.isEnabled = undoStack.isNotEmpty()
    undoBtn.setColorFilter(
      if (undoStack.isNotEmpty()) iconColor else dimmedIconColor,
      android.graphics.PorterDuff.Mode.SRC_IN
    )
    redoBtn.isEnabled = redoStack.isNotEmpty()
    redoBtn.setColorFilter(
      if (redoStack.isNotEmpty()) iconColor else dimmedIconColor,
      android.graphics.PorterDuff.Mode.SRC_IN
    )
  }

  // endregion
}
