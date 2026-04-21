//
//  VideoTrimmer.swift
//  VideoTrim
//
//  Created by Duc Trung Mai on 20/5/25.
//

import UIKit
import AVFoundation

// Controls that allows trimming a range and scrubbing a progress indicator
@available(iOS 13.0, *)
@IBDesignable class VideoTrimmer: UIControl {
    
    // events for changing selectedRange ("trimming")
    static let didBeginTrimmingFromStart = UIControl.Event(rawValue: 1 << 19)
    static let leadingGrabberChanged = UIControl.Event(rawValue: 1 << 20)
    static let didEndTrimmingFromStart = UIControl.Event(rawValue: 1 << 21)
    
    static let didBeginTrimmingFromEnd = UIControl.Event(rawValue: 1 << 22)
    static let trailingGrabberChanged = UIControl.Event(rawValue: 1 << 23)
    static let didEndTrimmingFromEnd = UIControl.Event(rawValue: 1 << 24)
    
    // events for scrubbing the progress indicator ("scrubbing")
    static let didBeginScrubbing = UIControl.Event(rawValue:    0b00001000 << 24)
    static let progressChanged = UIControl.Event(rawValue:      0b00010000 << 24)
    static let didEndScrubbing = UIControl.Event(rawValue:      0b00100000 << 24)
    
    // events for dragging the entire selected range
    static let didBeginDraggingRange = UIControl.Event(rawValue: 0b01000000 << 24)
    static let rangeDragChanged = UIControl.Event(rawValue:      0b10000000 << 24)
    static let didEndDraggingRange = UIControl.Event(rawValue:   1 << 25)
    
    private struct Thumbnail {
        let uuid = UUID()
        let imageView: UIImageView
        let time: CMTime
    }
    
    // currently there're warnings in the console saying that initial width of thumbView is 0
    // TODO: migrate all to AutoLayout
    let thumbView: VideoTrimmerThumb = {
        let view = VideoTrimmerThumb()
        view.accessibilityIdentifier = "thumbView"
        return view
    }()
    
    private let wrapperView: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "wrapperView"
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let shadowView: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "shadowView"
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    private let thumbnailClipView: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "thumbnailClipView"
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    private let thumbnailWrapperView: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "thumbnailWrapperView"
        
        return view
    }()
    
    private let thumbnailTrackView: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "thumbnailTrackView"
        
        return view
    }()
    
    private let thumbnailLeadingCoverView: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "thumbnailLeadingCoverView"
        
        return view
    }()
    
    private let thumbnailTrailingCoverView: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "thumbnailTrailingCoverView"
        
        return view
    }()
    
    private let leadingThumbRest: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "leadingThumbRest"
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let trailingThumbRest: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "trailingThumbRest"
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let progressIndicator: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "progressIndicator"
        return view
    }()
    
    private let progressIndicatorControl: UIControl = {
        let view = UIControl()
        view.accessibilityIdentifier = "progressIndicatorControl"
        
        return view
    }()
    
    // defines how much the control is insetted from its sides:
    // this is set to 16, so that you can have the control fullscreen (and have it
    // edge-to-edge when zooming in)
    @IBInspectable var horizontalInset: CGFloat = 16 {
        didSet {
            guard horizontalInset != oldValue else {return}
            setNeedsLayout()
        }
    }
    
    var asset: AVAsset? {
        didSet {
            // Clean up *all* async resources unconditionally — even when
            // asset is set to nil (e.g. editor dismissal triggers this via
            // VideoTrimmerViewController.viewWillDisappear).
            generator?.cancelAllCGImageGeneration()
            currentAssetReader?.cancelReading()
            currentAssetReader = nil
            audioDownloadTask?.cancel()
            audioDownloadTask = nil
            cleanupLocalAudioFile()
            localAudioAsset = nil
            
            if let asset = asset {
                applyThemeColors()
                let duration = asset.duration
                range = CMTimeRange(start: .zero, duration: duration)
                selectedRange = range
                lastKnownViewSizeForThumbnailGeneration = .zero
                lastKnownWaveformSize = .zero
                lastKnownWaveformRange = .zero
                setNeedsLayout()
            }
        }
    }
    
    // the video composition to use
    var videoComposition: AVVideoComposition? {
        didSet {
            lastKnownViewSizeForThumbnailGeneration = .zero
            setNeedsLayout()
        }
    }
    
    // a clip cannot be trimmed shorter than this duration
    var minimumDuration: CMTime = CMTime(seconds: 1, preferredTimescale: 600)
    var maximumDuration: CMTime = .positiveInfinity
    var enableHapticFeedback = true
    var zoomOnWaitingDuration: Double = 5.0 // Default: 5 seconds
    var isLightTheme = false
    /// Explicitly set from JS config (`type != "video"`).
    /// Using a dedicated flag instead of inspecting AVAsset tracks avoids
    /// false negatives — some audio files (e.g. M4A with album art) report
    /// a video track, which caused the original `.video` track guard to
    /// skip waveform generation entirely.
    var isAudioOnly = false {
        didSet {
            lastKnownWaveformSize = .zero
            setNeedsLayout()
        }
    }
    
    // MARK: - Waveform customisation (forwarded to AudioWaveformView)
    var waveformBarColor: UIColor = .white {
        didSet { waveformView.barColor = waveformBarColor }
    }
    var waveformBgColor: UIColor = UIColor(red: 0.204, green: 0.471, blue: 0.965, alpha: 1) {
        didSet { waveformView.backgroundColor = waveformBgColor }
    }
    var waveformBarWidth: CGFloat = 3 {
        didSet { waveformView.barWidth = waveformBarWidth }
    }
    var waveformBarGap: CGFloat = 2 {
        didSet { waveformView.barGap = waveformBarGap }
    }
    var waveformBarCornerRadius: CGFloat = 1.5 {
        didSet { waveformView.barCornerRadius = waveformBarCornerRadius }
    }
    
    // the available range of the asset.
    // Will be set to the full duration of the asset when assigning a new asset
    var range: CMTimeRange = .invalid {
        didSet {
            setNeedsLayout()
        }
    }
    
    // the range that is selected, will be set to the full duration
    // when changing asset.
    var selectedRange: CMTimeRange = .invalid {
        didSet {
            setNeedsLayout()
        }
    }
    
    // defines what to do with the progress indicator
    enum ProgressIndicatorMode {
        case hiddenOnlyWhenTrimming // the progress indicator gets hidden when the user starts trimming
        case alwaysShown // the progress indicator is always shown, even when the user is trimming
        case alwaysHidden // the progress indicator is never shown
    }
    var progressIndicatorMode = ProgressIndicatorMode.hiddenOnlyWhenTrimming {
        didSet {
            updateProgressIndicator()
        }
    }
    
    // defines where the progress indicator is shown.
    var progress: CMTime = .zero {
        didSet {
            setNeedsLayout()
        }
    }
    
    // defines if the user is trimming or not, and if so, which edge
    enum TrimmingState {
        case none        // user isn't trimming
        case leading    // user is trimming the leading part of the asset
        case trailing    // user is trimming the trailing part of the asset
    }
    
    private(set) var trimmingState = TrimmingState.none {
        didSet {
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.shadowView.layer.shadowOpacity = (self.trimmingState != .none ? 0.5 : 0.25)
                self.shadowView.layer.shadowRadius = (self.trimmingState != .none ? 4 : 2)
            })
        }
    }
    
    // yes if the user is zoomed in
    private(set) var isZoomedIn = false
    private(set) var zoomedInRange: CMTimeRange = .zero
    
    
    // yes if the user is scrubbing the progress indicator
    private(set) var isScrubbing = false
    
    var trackBackgroundColor = UIColor.black {
        didSet {
            thumbnailWrapperView.backgroundColor = trackBackgroundColor
        }
    }
    
    var thumbRestColor = UIColor.black {
        didSet {
            leadingThumbRest.backgroundColor = thumbRestColor
            trailingThumbRest.backgroundColor = thumbRestColor
        }
    }
    
    // the range that's currently visible: could be less than "range" when zoomed in
    var visibleRange: CMTimeRange  {
        return isZoomedIn == true ? zoomedInRange : range
    }
    
    // the time that's currently selected by the user when trimming
    var selectedTime: CMTime {
        switch trimmingState {
        case .none: return .zero
        case .leading: return selectedRange.start
        case .trailing: return selectedRange.end
        }
    }
    
    // gesture recognizers used. Can be used, for instance, to
    // require a tableview panGestureRecognizer to fail
    private (set) var leadingGestureRecognizer: UILongPressGestureRecognizer!
    private (set) var trailingGestureRecognizer: UILongPressGestureRecognizer!
    private (set) var progressGestureRecognizer: UILongPressGestureRecognizer!
    private (set) var thumbnailInteractionGestureRecognizer: UILongPressGestureRecognizer!
    private (set) var rangeDragGestureRecognizer: UILongPressGestureRecognizer!
    
    // range drag state
    private(set) var isDraggingRange = false
    private var rangeDragInitialRange: CMTimeRange = .zero
    private var rangeDragInitialLocationX: CGFloat = 0
    
    // private stuff
    private var grabberOffset = CGFloat(0)
    private var zoomWaitTimer: Timer?
    
    private var lastKnownViewSizeForThumbnailGeneration: CGSize = .zero
    private var thumbnailSize: CGSize = .zero
    private var lastKnownThumbnailRange: CMTimeRange = .zero
    private var thumbnails = Array<Thumbnail>()
    private var generator: AVAssetImageGenerator?
    
    // MARK: - Audio waveform state
    //
    // AVAssetReader cannot read from remote URLs, so for remote audio we
    // download to a temporary local file first (via URLSession.downloadTask).
    // The local AVURLAsset is reused for zoom re-extractions, and the temp
    // file is deleted in cleanupLocalAudioFile() on dismiss.
    private let waveformView = AudioWaveformView()
    private var lastKnownWaveformSize: CGSize = .zero
    private var lastKnownWaveformRange: CMTimeRange = .zero
    private var currentAssetReader: AVAssetReader?
    /** AVURLAsset pointing to the downloaded local file (nil for local sources). */
    private var localAudioAsset: AVURLAsset?
    /** File URL of the temporary download, for deletion on cleanup. */
    private var localAudioFileURL: URL?
    private var audioDownloadTask: URLSessionDownloadTask?
    
    private var impactFeedbackGenerator: UIImpactFeedbackGenerator?
    private var didClampWhilePanning = false
    
    
    /// Cancel all in-flight async work and delete temporary files.
    /// This fires both on normal dismiss and on immediate close.
    deinit {
        generator?.cancelAllCGImageGeneration()
        audioDownloadTask?.cancel()
        currentAssetReader?.cancelReading()
        cleanupLocalAudioFile()
    }
    
    // MARK: - Private
    private func applyThemeColors() {
        let bg: UIColor = isLightTheme ? .white : .black
        let coverAlpha: CGFloat = isLightTheme ? 0.6 : 0.75
        trackBackgroundColor = bg
        thumbRestColor = bg
        thumbnailLeadingCoverView.backgroundColor = UIColor(white: isLightTheme ? 1 : 0, alpha: coverAlpha)
        thumbnailTrailingCoverView.backgroundColor = UIColor(white: isLightTheme ? 1 : 0, alpha: coverAlpha)
        shadowView.layer.shadowColor = (isLightTheme ? UIColor.gray : UIColor.black).cgColor
    }
    
    private func setup() {
        addSubview(thumbnailClipView)
        thumbnailClipView.addSubview(thumbnailWrapperView)
        thumbnailWrapperView.addSubview(leadingThumbRest)
        thumbnailWrapperView.addSubview(trailingThumbRest)
        thumbnailWrapperView.addSubview(thumbnailTrackView)
        
        // Waveform view sits inside the thumbnail track but starts hidden;
        // it's shown only for audio files once data is available.
        waveformView.backgroundColor = waveformBgColor
        waveformView.barColor = waveformBarColor
        waveformView.barWidth = waveformBarWidth
        waveformView.barGap = waveformBarGap
        waveformView.barCornerRadius = waveformBarCornerRadius
        waveformView.isHidden = true
        thumbnailTrackView.addSubview(waveformView)
        
        thumbnailWrapperView.addSubview(thumbnailLeadingCoverView)
        thumbnailWrapperView.addSubview(thumbnailTrailingCoverView)
        
        progressIndicator.layer.shadowOffset = .zero
        progressIndicator.layer.shadowRadius = 2
        progressIndicator.layer.shadowOpacity = 0.25
        progressIndicator.layer.cornerRadius = 2
        progressIndicator.layer.cornerCurve = .continuous
        
        addSubview(shadowView)
        wrapperView.clipsToBounds = true
        shadowView.addSubview(wrapperView)
        wrapperView.addSubview(thumbView)
        wrapperView.addSubview(progressIndicator)
        wrapperView.addSubview(progressIndicatorControl)
        
        thumbnailClipView.clipsToBounds = true
        thumbnailTrackView.clipsToBounds = true
        
        thumbnailWrapperView.layer.cornerRadius = 6
        thumbnailWrapperView.layer.cornerCurve = .continuous
        
        leadingThumbRest.layer.cornerRadius = 6
        leadingThumbRest.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
        leadingThumbRest.layer.cornerCurve = .continuous
        
        trailingThumbRest.layer.cornerRadius = 6
        trailingThumbRest.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
        trailingThumbRest.layer.cornerCurve = .continuous
        
        shadowView.layer.shadowOffset = .zero
        shadowView.layer.shadowRadius = 2
        shadowView.layer.shadowOpacity = 0.25
        
        // Apply default (dark theme) colors — overridden by applyThemeColors() when asset is set
        progressIndicator.backgroundColor = .white
        progressIndicator.layer.shadowColor = UIColor.black.cgColor
        thumbnailLeadingCoverView.backgroundColor = UIColor(white: 0, alpha: 0.75)
        thumbnailTrailingCoverView.backgroundColor = UIColor(white: 0, alpha: 0.75)
        leadingThumbRest.backgroundColor = thumbRestColor
        trailingThumbRest.backgroundColor = thumbRestColor
        thumbnailWrapperView.backgroundColor = trackBackgroundColor
        shadowView.layer.shadowColor = UIColor.black.cgColor
        
        setupConstraints()
        setupGestures()
    }
    
    //            thumbView.topAnchor.constraint(equalTo: thumbnailWrapperView.topAnchor),
    //            thumbView.bottomAnchor.constraint(equalTo: thumbnailWrapperView.bottomAnchor),
    //            thumbView.leadingAnchor.constraint(equalTo: thumbnailWrapperView.leadingAnchor),
    //            thumbView.trailingAnchor.constraint(equalTo: thumbnailWrapperView.trailingAnchor),
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            thumbnailClipView.topAnchor.constraint(equalTo: self.topAnchor),
            thumbnailClipView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            thumbnailClipView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            thumbnailClipView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            
            shadowView.topAnchor.constraint(equalTo: self.topAnchor),
            shadowView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            shadowView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            shadowView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            
            wrapperView.topAnchor.constraint(equalTo: shadowView.topAnchor),
            wrapperView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),
            wrapperView.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            wrapperView.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            
            leadingThumbRest.topAnchor.constraint(equalTo: thumbnailWrapperView.topAnchor),
            leadingThumbRest.bottomAnchor.constraint(equalTo: thumbnailWrapperView.bottomAnchor),
            leadingThumbRest.leadingAnchor.constraint(equalTo: thumbnailWrapperView.leadingAnchor),
            leadingThumbRest.widthAnchor.constraint(equalToConstant: thumbView.chevronWidth),
            
            trailingThumbRest.topAnchor.constraint(equalTo: thumbnailWrapperView.topAnchor),
            trailingThumbRest.bottomAnchor.constraint(equalTo: thumbnailWrapperView.bottomAnchor),
            trailingThumbRest.trailingAnchor.constraint(equalTo: thumbnailWrapperView.trailingAnchor),
            trailingThumbRest.widthAnchor.constraint(equalToConstant: thumbView.chevronWidth),
        ])
    }
    
    private func setupGestures() {
        leadingGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(leadingGrabberPanned(_:)))
        leadingGestureRecognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
        leadingGestureRecognizer.minimumPressDuration = 0
        thumbView.leadingGrabber.addGestureRecognizer(leadingGestureRecognizer)
        
        trailingGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(trailingGrabberPanned(_:)))
        trailingGestureRecognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
        trailingGestureRecognizer.minimumPressDuration = 0
        thumbView.trailingGrabber.addGestureRecognizer(trailingGestureRecognizer)
        
        progressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(progressGrabberPanned(_:)))
        progressGestureRecognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
        progressGestureRecognizer.minimumPressDuration = 0
        progressGestureRecognizer.require(toFail: leadingGestureRecognizer)
        progressGestureRecognizer.require(toFail: trailingGestureRecognizer)
        progressIndicatorControl.addGestureRecognizer(progressGestureRecognizer)
        
        // Range drag: platform-default long press (0.5s hold, 10pt allowable movement)
        rangeDragGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(rangeDragPanned(_:)))
        rangeDragGestureRecognizer.require(toFail: leadingGestureRecognizer)
        rangeDragGestureRecognizer.require(toFail: trailingGestureRecognizer)
        thumbView.addGestureRecognizer(rangeDragGestureRecognizer)
        
        thumbnailInteractionGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(thumbnailPanned(_:)))
        thumbnailInteractionGestureRecognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
        thumbnailInteractionGestureRecognizer.minimumPressDuration = 0
        thumbnailInteractionGestureRecognizer.require(toFail: leadingGestureRecognizer)
        thumbnailInteractionGestureRecognizer.require(toFail: trailingGestureRecognizer)
        thumbnailInteractionGestureRecognizer.require(toFail: rangeDragGestureRecognizer)
        thumbView.addGestureRecognizer(thumbnailInteractionGestureRecognizer)
    }
    
    private func regenerateThumbnailsIfNeeded() {
        let size = bounds.size
        guard size.width > 0 && size.height > 0 else {return}
        guard lastKnownViewSizeForThumbnailGeneration != size || CMTimeRangeEqual(lastKnownThumbnailRange, visibleRange) == false else {return}
        guard let asset = asset else {return}
        guard let track = asset.tracks(withMediaType: .video).first else {return}
        
        lastKnownViewSizeForThumbnailGeneration = size
        lastKnownThumbnailRange = visibleRange
        
        let naturalSize = track.naturalSize
        let transform = track.preferredTransform
        let fixedSize = naturalSize.applyingVideoTransform(transform)
        
        self.generator?.cancelAllCGImageGeneration()
        let generator = AVAssetImageGenerator(asset: asset)
        generator.apertureMode = .cleanAperture
        generator.videoComposition = videoComposition
        self.generator = generator
        
        let height = size.height - thumbView.edgeHeight * 2
        thumbnailSize = CGSize(width: height / fixedSize.height * fixedSize.width, height: height)
        let numberOfThumbnails = Int(ceil(size.width / thumbnailSize.width))
        
        var newThumbnails = Array<Thumbnail>()
        let thumbnailDuration = visibleRange.duration.seconds / Double(numberOfThumbnails)
        var times = Array<NSValue>()
        // we add some extra thumbnails as padding
        for index in -3..<numberOfThumbnails + 6 {
            let time = CMTimeAdd(visibleRange.start, CMTime(seconds: thumbnailDuration * Double(index), preferredTimescale: asset.duration.timescale * 2))
            guard CMTimeCompare(time, .zero) != -1 else {continue}
            times.append(NSValue(time: time))
            
            let newThumbnail = Thumbnail(imageView: UIImageView(), time: time)
            self.thumbnailTrackView.addSubview(newThumbnail.imageView)
            newThumbnails.append(newThumbnail)
        }
        
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: thumbnailSize.width * UIScreen.main.scale, height: thumbnailSize.height * UIScreen.main.scale)
        
        let oldThumbnails = thumbnails
        thumbnails.append(contentsOf: newThumbnails)
        
        UIView.animate(withDuration: 0.25, delay: 0.25, options: [.beginFromCurrentState], animations: {
            oldThumbnails.forEach {$0.imageView.alpha = 0}
        }, completion: { _ in
            oldThumbnails.forEach {$0.imageView.removeFromSuperview()}
            let uuidsToRemove = Set(oldThumbnails.map({$0.uuid}))
            self.thumbnails.removeAll(where: {uuidsToRemove.contains($0.uuid)})
        })
        
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgImage, actualTime, result, error in
            DispatchQueue.main.async {
                guard let cgImage = cgImage else {return}
                guard let index = newThumbnails.firstIndex(where: { CMTimeCompare($0.time, requestedTime) == 0 }) else {return}
                let image = UIImage(cgImage: cgImage)
                
                let imageView = newThumbnails[index].imageView
                UIView.transition(with: imageView, duration: 0.25, options: [.transitionCrossDissolve], animations: {
                    imageView.image = image
                })
            }
        }
    }
    
    /// Called from layoutSubviews whenever the view size or visible time range changes.
    ///
    /// For remote URLs, the first call triggers a download; once the local
    /// file is cached, subsequent calls (e.g. zoom) skip straight to reading.
    private func regenerateWaveformIfNeeded() {
        guard isAudioOnly else { return }
        let size = bounds.size
        guard size.width > 0 && size.height > 0 else { return }
        guard lastKnownWaveformSize != size || !CMTimeRangeEqual(lastKnownWaveformRange, visibleRange) else { return }
        guard let asset = asset else { return }
        
        // Remote URL path: download once, then reuse localAudioAsset for reads
        if let urlAsset = asset as? AVURLAsset, !urlAsset.url.isFileURL {
            if let localAsset = localAudioAsset {
                guard let audioTrack = localAsset.tracks(withMediaType: .audio).first else { return }
                readWaveformSamples(from: localAsset, audioTrack: audioTrack, size: size)
            } else if audioDownloadTask == nil {
                downloadAudioForWaveform(from: urlAsset.url)
            }
            return
        }
        
        // Local file path: read directly
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else { return }
        readWaveformSamples(from: asset, audioTrack: audioTrack, size: size)
    }
    
    /// Download remote audio to a temporary local file so AVAssetReader can read it.
    ///
    /// The file extension is inferred from the HTTP response (Content-Disposition,
    /// MIME type) or the original URL, because AVURLAsset on iOS relies on
    /// the extension to identify the audio codec — a generic `.tmp` extension
    /// would cause silent failures.
    private func downloadAudioForWaveform(from url: URL) {
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self, let tempURL = tempURL else {
                print("AudioWaveform: Download failed: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async { self?.audioDownloadTask = nil }
                return
            }
            
            let ext = Self.audioFileExtension(from: response, originalURL: url)
            let destURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("waveform_\(UUID().uuidString).\(ext)")
            do {
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                let localAsset = AVURLAsset(url: destURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                localAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
                    var trackError: NSError?
                    let status = localAsset.statusOfValue(forKey: "tracks", error: &trackError)
                    guard status == .loaded else {
                        print("AudioWaveform: Failed to load tracks from downloaded file: \(trackError?.localizedDescription ?? "unknown")")
                        try? FileManager.default.removeItem(at: destURL)
                        DispatchQueue.main.async { self.audioDownloadTask = nil }
                        return
                    }
                    DispatchQueue.main.async {
                        self.localAudioFileURL = destURL
                        self.localAudioAsset = localAsset
                        self.audioDownloadTask = nil
                        self.lastKnownWaveformSize = .zero
                        self.setNeedsLayout()
                    }
                }
            } catch {
                print("AudioWaveform: Failed to move downloaded file: \(error)")
                DispatchQueue.main.async { self.audioDownloadTask = nil }
            }
        }
        audioDownloadTask = task
        task.resume()
    }
    
    /// Determine the correct audio file extension from the HTTP response.
    /// Priority: Content-Disposition → MIME type → URL path extension → "m4a" fallback.
    private static func audioFileExtension(from response: URLResponse?, originalURL: URL) -> String {
        if let suggested = response?.suggestedFilename, !suggested.isEmpty {
            let ext = (suggested as NSString).pathExtension
            if !ext.isEmpty { return ext }
        }
        
        if let mimeType = response?.mimeType?.lowercased() {
            switch mimeType {
            case "audio/mpeg", "audio/mp3": return "mp3"
            case "audio/mp4", "audio/x-m4a", "audio/aac": return "m4a"
            case "audio/wav", "audio/x-wav", "audio/wave": return "wav"
            case "audio/flac": return "flac"
            case "audio/ogg", "audio/vorbis": return "ogg"
            case "audio/aiff", "audio/x-aiff": return "aiff"
            default: break
            }
        }
        
        let urlExt = originalURL.pathExtension
        if !urlExt.isEmpty { return urlExt }
        
        return "m4a"
    }
    
    /// Decode PCM samples from the given asset's audio track and compute
    /// per-bar RMS amplitudes normalised to [0, 1].
    ///
    /// Runs the heavy decode on a background queue and posts the result
    /// back to the main thread. The AVAssetReader is stored in
    /// `currentAssetReader` so it can be cancelled if the editor is closed
    /// or the view resizes mid-read.
    private func readWaveformSamples(from asset: AVAsset, audioTrack: AVAssetTrack, size: CGSize) {
        lastKnownWaveformSize = size
        lastKnownWaveformRange = visibleRange
        
        waveformView.isHidden = false
        
        currentAssetReader?.cancelReading()
        currentAssetReader = nil
        
        let timeRange = visibleRange
        let step = waveformBarWidth + waveformBarGap
        let barCount = max(1, Int(floor(size.width / step)))
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let reader: AVAssetReader
            do {
                reader = try AVAssetReader(asset: asset)
            } catch {
                print("AudioWaveform: Failed to create AVAssetReader: \(error)")
                return
            }
            
            reader.timeRange = timeRange
            
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVNumberOfChannelsKey: 1,
            ]
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            
            guard reader.canAdd(output) else {
                print("AudioWaveform: Cannot add output to reader")
                return
            }
            reader.add(output)
            
            DispatchQueue.main.sync {
                self.currentAssetReader = reader
            }
            
            guard reader.startReading() else {
                print("AudioWaveform: Failed to start reading: \(String(describing: reader.error))")
                return
            }
            
            var allSamples = [Float]()
            allSamples.reserveCapacity(barCount * 512)
            
            while reader.status == .reading {
                guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
                guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
                
                let length = CMBlockBufferGetDataLength(blockBuffer)
                let sampleCount = length / MemoryLayout<Float>.size
                guard sampleCount > 0 else { continue }
                
                var data = [Float](repeating: 0, count: sampleCount)
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &data)
                allSamples.append(contentsOf: data)
            }
            
            guard !allSamples.isEmpty else {
                DispatchQueue.main.async {
                    self.waveformView.amplitudes = []
                }
                return
            }
            
            let samplesPerBar = max(1, allSamples.count / barCount)
            var amplitudes = [CGFloat]()
            amplitudes.reserveCapacity(barCount)
            
            for i in 0..<barCount {
                let start = i * samplesPerBar
                let end = min(start + samplesPerBar, allSamples.count)
                guard start < allSamples.count else {
                    amplitudes.append(0)
                    continue
                }
                
                var sumSquares: Float = 0
                for j in start..<end {
                    let s = allSamples[j]
                    sumSquares += s * s
                }
                let rms = sqrt(sumSquares / Float(end - start))
                amplitudes.append(CGFloat(rms))
            }
            
            let maxAmp = amplitudes.max() ?? 1
            let normalizer: CGFloat = maxAmp > 0 ? 1.0 / maxAmp : 1.0
            let normalized = amplitudes.map { min($0 * normalizer, 1.0) }
            
            DispatchQueue.main.async {
                self.waveformView.amplitudes = normalized
            }
        }
    }
    
    /// Delete the temporary local audio file created by downloadAudioForWaveform.
    private func cleanupLocalAudioFile() {
        if let url = localAudioFileURL {
            try? FileManager.default.removeItem(at: url)
            localAudioFileURL = nil
        }
    }
    
    private func timeForLocation(_ x: CGFloat) -> CMTime {
        let size = bounds.size
        let inset = thumbView.chevronWidth + horizontalInset
        let offset = x - inset
        
        let availableWidth = size.width - inset * 2
        let visibleDurationInSeconds = CGFloat(visibleRange.duration.seconds)
        let ratio = visibleDurationInSeconds != 0 ? availableWidth / visibleDurationInSeconds : 0
        
        let timeDifference = CMTime(seconds: Double(offset / ratio), preferredTimescale: 600)
        return CMTimeAdd(visibleRange.start, timeDifference)
    }
    
    private func locationForTime(_ time: CMTime) -> CGFloat {
        let size = bounds.size
        let inset = thumbView.chevronWidth + horizontalInset
        let availableWidth = size.width - inset * 2
        
        let offset = CMTimeSubtract(time, visibleRange.start)
        
        let visibleDurationInSeconds = CGFloat(visibleRange.duration.seconds)
        let ratio = visibleDurationInSeconds != 0 ? availableWidth / visibleDurationInSeconds : 0
        
        let location = CGFloat(offset.seconds) * ratio
        return SnapToDevicePixels(location) + inset
    }
    
    private func startZoomWaitTimer() {
        stopZoomWaitTimer()
        guard isZoomedIn == false else {return}
        zoomWaitTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { [weak self] _ in
            guard let self = self else {return}
            self.stopZoomWaitTimer()
            self.zoomIfNeeded()
        })
    }
    
    private func stopZoomWaitTimer() {
        zoomWaitTimer?.invalidate()
        zoomWaitTimer = nil
    }
    
    private func stopZoomIfNeeded() {
        stopZoomWaitTimer()
        isZoomedIn = false
        animateChanges()
    }
    
    private func zoomIfNeeded() {
        guard isZoomedIn == false else {return}
        
        let size = bounds.size
        let inset = thumbView.chevronWidth + horizontalInset
        let availableWidth = size.width - inset * 2
        
        // Use configurable zoom duration, but ensure it's reasonable for the video
        var newDuration = zoomOnWaitingDuration
        
        // For very short videos, use a smaller zoom range
        if range.duration.seconds < 2.0 {
            newDuration = max(0.5, range.duration.seconds * 0.5) // At least 0.5 seconds for very short videos
        } else if range.duration.seconds < zoomOnWaitingDuration {
            newDuration = max(1.0, range.duration.seconds * 0.5) // Use half duration for short videos
        }
        
        // Ensure zoom duration doesn't exceed video duration
        newDuration = min(newDuration, range.duration.seconds)
        
        print("Zoom activated - Video duration: \(range.duration.seconds)s, Configured zoom: \(zoomOnWaitingDuration)s, Actual zoom: \(newDuration)s")
        
        let durationTime = CMTime(seconds: newDuration, preferredTimescale: 600)
        
        if trimmingState == .leading {
            let position = locationForTime(selectedRange.start) - inset
            let start = position / availableWidth * CGFloat(newDuration)
            zoomedInRange = CMTimeRange(start: CMTimeSubtract(selectedRange.start, CMTime(seconds: Double(start), preferredTimescale: 600)), duration: durationTime)
        } else {
            let position = locationForTime(selectedRange.end) - inset
            
            let durationToStart = position / availableWidth * CGFloat(newDuration)
            let newStart = CMTimeSubtract(selectedRange.end, CMTime(seconds: Double(durationToStart), preferredTimescale: 600))
            zoomedInRange = CMTimeRange(start: newStart, duration: durationTime)
        }
        
        isZoomedIn = true
        animateChanges()
        
        if enableHapticFeedback {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
    
    private func animateChanges() {
        setNeedsLayout()
        thumbView.setNeedsLayout()
        UIView.animate(withDuration: 0.5, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
            self.layoutIfNeeded()
            self.thumbView.layoutIfNeeded()
        })
    }
    
    private func startPanning() {
        didClampWhilePanning = false
        
        if enableHapticFeedback {
            UISelectionFeedbackGenerator().selectionChanged()
            impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedbackGenerator?.prepare()
        }
        
        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
            self.updateProgressIndicator()
        })
    }
    
    private func stopPanning() {
        trimmingState = .none
        stopZoomIfNeeded()
        impactFeedbackGenerator = nil
        
        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
            self.updateProgressIndicator()
        })
    }
    
    private func updateProgressIndicator() {
        switch progressIndicatorMode {
        case .alwaysHidden:
            progressIndicator.alpha = 0
            progressIndicatorControl.isUserInteractionEnabled = false
            
        case .alwaysShown:
            progressIndicator.alpha = 1
            progressIndicatorControl.isUserInteractionEnabled = true
            setNeedsLayout()
            
        case .hiddenOnlyWhenTrimming:
            let shouldShow = trimmingState == .none && !isDraggingRange
            progressIndicator.alpha = (shouldShow ? 1 : 0)
            progressIndicatorControl.isUserInteractionEnabled = shouldShow
            if shouldShow {
                setNeedsLayout()
                if UIView.inheritedAnimationDuration > 0 {
                    UIView.performWithoutAnimation {
                        layoutIfNeeded()
                    }
                }
            }
        }
        progressIndicatorControl.alpha = progressIndicator.alpha
    }
    
    
    // MARK: - Input
    @objc private func thumbnailPanned(_ sender: UILongPressGestureRecognizer) {
        progressGrabberPanned(sender)
    }
    
    
    @objc private func progressGrabberPanned(_ sender: UILongPressGestureRecognizer) {
        
        func handleChanged() {
            let location = sender.location(in: self)
            var time = timeForLocation(location.x + grabberOffset)
            
            var didClamp = false
            if CMTimeCompare(time, selectedRange.start) == -1 {
                time = selectedRange.start
                didClamp = true
            }
            if CMTimeCompare(time, selectedRange.end) == 1 {
                time = selectedRange.end
                didClamp = true
            }
            
            if didClamp == true && didClamp != didClampWhilePanning {
                impactFeedbackGenerator?.impactOccurred()
            }
            didClampWhilePanning = didClamp
            
            progress = time
            setNeedsLayout()
            sendActions(for: Self.progressChanged)
        }
        switch sender.state {
        case .began:
            if enableHapticFeedback {
                UISelectionFeedbackGenerator().selectionChanged()
                impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedbackGenerator?.prepare()
            }
            
            didClampWhilePanning = false
            
            isScrubbing = true
            sendActions(for: Self.didBeginScrubbing)
            handleChanged()
            
        case .changed:
            handleChanged()
            
        case .ended, .cancelled:
            impactFeedbackGenerator = nil
            
            isScrubbing = false
            sendActions(for: Self.didEndScrubbing)
            
        case .possible, .failed:
            break
            
        @unknown default:
            break
        }
    }
    
    
    @objc private func leadingGrabberPanned(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            trimmingState = .leading
            grabberOffset = thumbView.chevronWidth - sender.location(in: thumbView.leadingGrabber).x
            
            startPanning()
            sendActions(for: Self.didBeginTrimmingFromStart)
            
        case .changed:
            let location = sender.location(in: self)
            let current = timeForLocation(location.x + grabberOffset)
            let min = CMTimeSubtract(selectedRange.end, minimumDuration)
            
            var didClamp = false
            var newRange = CMTimeRange(start: current, end: selectedRange.end)
            
            if CMTimeCompare(current, min) != -1 {
                newRange = CMTimeRange(start: min, end: selectedRange.end)
                didClamp = true
            } else if CMTimeCompare(newRange.duration, maximumDuration) != -1 {
                let time = CMTimeSubtract(selectedRange.end, maximumDuration)
                newRange = CMTimeRange(start: time, end: selectedRange.end)
                didClamp = true
            } else if CMTimeCompare(newRange.start, range.start) != 1 {
                // prevent startTime to be smaller than video startTime
                newRange = CMTimeRange(start: range.start, end: selectedRange.end)
                didClamp = true
            } else if CMTimeCompare(newRange.duration, minimumDuration) != 1 {
                newRange = CMTimeRange(start: min, end: selectedRange.end)
                didClamp = true
            }
            
            if didClamp == true && didClamp != didClampWhilePanning {
                impactFeedbackGenerator?.impactOccurred()
            }
            
            didClampWhilePanning = didClamp
            selectedRange = newRange
            sendActions(for: Self.leadingGrabberChanged)
            setNeedsLayout()
            
            startZoomWaitTimer()
            
        case .ended:
            stopPanning()
            sendActions(for: Self.didEndTrimmingFromStart)
            
        case .cancelled:
            stopPanning()
            
        case .possible, .failed:
            break
            
        @unknown default:
            break
        }
    }
    
    @objc private func trailingGrabberPanned(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            trimmingState = .trailing
            grabberOffset = sender.location(in: thumbView.trailingGrabber).x
            
            startPanning()
            sendActions(for: Self.didBeginTrimmingFromEnd)
            
        case .changed:
            let location = sender.location(in: self)
            
            let current = timeForLocation(location.x - grabberOffset)
            let min = CMTimeAdd(selectedRange.start, minimumDuration)
            
            var didClamp = false
            var newRange = CMTimeRange(start: selectedRange.start, end: timeForLocation(location.x - grabberOffset))
            
            if CMTimeCompare(current, min) == -1 {
                newRange = CMTimeRange(start: selectedRange.start, end: min)
                didClamp = true
            } else if CMTimeCompare(newRange.duration, maximumDuration) != -1 {
                let time = CMTimeAdd(selectedRange.start, maximumDuration)
                newRange = CMTimeRange(start: selectedRange.start, end: time)
                didClamp = true
            } else if CMTimeCompare(newRange.end, range.end) != -1 {
                // prevent endTime to be greater than video endTime
                newRange = CMTimeRange(start: selectedRange.start, end: range.end)
                didClamp = true
            } else if CMTimeCompare(newRange.duration, minimumDuration) != 1 {
                newRange = CMTimeRange(start: selectedRange.start, end: min)
                didClamp = true
            }
            
            if didClamp == true && didClamp != didClampWhilePanning {
                impactFeedbackGenerator?.impactOccurred()
            }
            
            didClampWhilePanning = didClamp
            selectedRange = newRange
            sendActions(for: Self.trailingGrabberChanged)
            setNeedsLayout()
            
            startZoomWaitTimer()
            
        case .ended:
            stopPanning()
            sendActions(for: Self.didEndTrimmingFromEnd)
            
        case .cancelled:
            stopPanning()
            
        case .possible, .failed:
            break
            
        @unknown default:
            break
        }
    }
    
    
    @objc private func rangeDragPanned(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            isDraggingRange = true
            rangeDragInitialRange = selectedRange
            rangeDragInitialLocationX = sender.location(in: self).x
            didClampWhilePanning = false
            
            if enableHapticFeedback {
                UISelectionFeedbackGenerator().selectionChanged()
                impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedbackGenerator?.prepare()
            }
            
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.updateProgressIndicator()
            })
            sendActions(for: Self.didBeginDraggingRange)
            
        case .changed:
            let currentX = sender.location(in: self).x
            let deltaX = currentX - rangeDragInitialLocationX
            let inset = thumbView.chevronWidth + horizontalInset
            let availableWidth = bounds.width - inset * 2
            let visibleDurationInSeconds = CGFloat(visibleRange.duration.seconds)
            guard availableWidth > 0 && visibleDurationInSeconds > 0 else { return }
            
            let deltaTime = CMTime(
                seconds: Double(deltaX / availableWidth) * Double(visibleDurationInSeconds),
                preferredTimescale: 600
            )
            let duration = rangeDragInitialRange.duration
            var newStart = CMTimeAdd(rangeDragInitialRange.start, deltaTime)
            var newEnd = CMTimeAdd(newStart, duration)
            
            var didClamp = false
            if CMTimeCompare(newStart, range.start) == -1 {
                newStart = range.start
                newEnd = CMTimeAdd(newStart, duration)
                didClamp = true
            }
            if CMTimeCompare(newEnd, range.end) == 1 {
                newEnd = range.end
                newStart = CMTimeSubtract(newEnd, duration)
                didClamp = true
            }
            
            if didClamp && !didClampWhilePanning {
                impactFeedbackGenerator?.impactOccurred()
            }
            didClampWhilePanning = didClamp
            
            selectedRange = CMTimeRange(start: newStart, end: newEnd)
            setNeedsLayout()
            sendActions(for: Self.rangeDragChanged)
            
        case .ended:
            isDraggingRange = false
            impactFeedbackGenerator = nil
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.updateProgressIndicator()
            })
            sendActions(for: Self.didEndDraggingRange)
            
        case .cancelled:
            isDraggingRange = false
            impactFeedbackGenerator = nil
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.updateProgressIndicator()
            })
            
        case .possible, .failed:
            break
            
        @unknown default:
            break
        }
    }
    
    // MARK: - UIView
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 50)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = bounds.size
        let inset = thumbView.chevronWidth
        var left = locationForTime(selectedRange.start) - inset
        var right = locationForTime(selectedRange.end) + inset
        
        if right > bounds.width {
            right = bounds.width + inset * 2
        }
        
        if left < 0 {
            left = -inset
        }
        
        let rect = CGRect(origin: .zero, size: size)
        thumbView.frame = CGRect(x: left, y: 0, width: max(right - left, inset * 2), height: size.height)
        
        let isZoomedToEnd = (trimmingState == .leading && isZoomedIn == true)
        
        let thumbnailOffset = (isZoomedIn == true ? horizontalInset + inset + 6 : 0)
        let coverOffset = thumbnailOffset - horizontalInset
        let coverStartOffset = (isZoomedIn == false ? inset : 0)
        
        let thumbnailRect = rect.insetBy(dx: horizontalInset - thumbnailOffset, dy: thumbView.edgeHeight)
        thumbnailWrapperView.frame = thumbnailRect
        thumbnailTrackView.frame = CGRect(origin: .zero, size: CGSize(width: thumbnailRect.width - (isZoomedToEnd == false ? inset : 0), height: thumbnailRect.height))
        thumbnailLeadingCoverView.frame = CGRect(x: coverStartOffset, y: 0, width: left + inset * 0.5 + coverOffset - coverStartOffset, height: thumbnailRect.height)
        thumbnailTrailingCoverView.frame = CGRect(x: right - inset * 0.5 + coverOffset, y: 0, width: thumbnailRect.width - coverStartOffset - (right - inset * 0.5 + coverOffset), height: thumbnailRect.height)
        
        if progressIndicator.alpha > 0 {
            let progressWidth = CGFloat(4)
            let progressIndicatorOffset = locationForTime(progress)
            let progressLeft = min(max(thumbView.frame.minX + inset, progressIndicatorOffset - progressWidth * 0.5), thumbView.frame.maxX - inset - progressWidth)
            progressIndicator.frame = CGRect(x: progressLeft, y: thumbnailRect.minY, width: progressWidth, height: thumbnailRect.height)
            
            let progressControlWidth = CGFloat(24)
            
            var progressControlLeft = max(thumbView.frame.minX + inset, progressLeft)
            var progressControlRight = progressLeft + progressControlWidth
            if progressControlRight > thumbView.frame.maxX - inset {
                progressControlRight = thumbView.frame.maxX - inset
                progressControlLeft = max(thumbView.frame.minX + inset, progressControlRight - progressControlWidth)
            }
            progressIndicatorControl.frame = CGRect(x: progressControlLeft, y: thumbnailRect.minY, width: progressControlRight - progressControlLeft, height: thumbnailRect.height)
        }
        
        regenerateThumbnailsIfNeeded()
        regenerateWaveformIfNeeded()
        // Inset waveformView by the leading handle's chevron width so its
        // background doesn't bleed underneath the translucent handle area.
        let waveformLeft = thumbView.chevronWidth
        waveformView.frame = CGRect(x: waveformLeft, y: 0, width: max(0, thumbnailTrackView.bounds.width - waveformLeft), height: thumbnailTrackView.bounds.height)
        
        for thumbnail in thumbnails {
            let position = locationForTime(thumbnail.time) - horizontalInset + thumbnailOffset
            let frame = CGRect(x: position, y: 0, width: thumbnailSize.width, height: thumbnailSize.height)
            if thumbnail.imageView.bounds.width == 0 {
                UIView.performWithoutAnimation {
                    thumbnail.imageView.frame = frame
                }
            } else {
                thumbnail.imageView.frame = frame
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
}

// MARK: -

fileprivate func SnapToDevicePixels(_ value: CGFloat, scale: CGFloat? = nil) -> CGFloat {
    let actualScale = scale ?? UIScreen.main.scale
    return round(value * actualScale) / actualScale
}

fileprivate func SnapToDevicePixels(_ rect: CGRect, scale: CGFloat? = nil) -> CGRect {
    return CGRect(x: SnapToDevicePixels(rect.origin.x, scale: scale),
                  y: SnapToDevicePixels(rect.origin.y, scale: scale),
                  width: SnapToDevicePixels(rect.maxX - rect.minX, scale: scale),
                  height: SnapToDevicePixels(rect.maxY - rect.minY, scale: scale))
}

fileprivate extension CGRect {
    func snappedToDevicePixels(scale: CGFloat? = nil) -> CGRect {
        return SnapToDevicePixels(self, scale: scale)
    }
}

fileprivate extension CGSize {
    func applyingVideoTransform(_ transform: CGAffineTransform) -> CGSize {
        return CGRect(origin: .zero, size: self).applying(transform).size
    }
}
