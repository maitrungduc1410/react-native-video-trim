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
    
    private struct Thumbnail {
        let uuid = UUID()
        let imageView: UIImageView
        let time: CMTime
    }
    
    // currently there're warnings in the console saying that initial width of thumbView is 0
    // TODO: migrate all to AutoLayout
    private let thumbView: VideoTrimmerThumb = {
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
    
    // the asset to use
    var asset: AVAsset? {
        didSet {
            if let asset = asset {
                let duration = asset.duration
                range = CMTimeRange(start: .zero, duration: duration)
                selectedRange = range
                lastKnownViewSizeForThumbnailGeneration = .zero
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
    
    // background color for the track
    var trackBackgroundColor = UIColor.black {
        didSet {
            thumbnailWrapperView.backgroundColor = trackBackgroundColor
        }
    }
    
    // background color for the place where the thumbs rest on when the selectedRange == range
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
    
    // private stuff
    private var grabberOffset = CGFloat(0)
    private var zoomWaitTimer: Timer?
    
    private var lastKnownViewSizeForThumbnailGeneration: CGSize = .zero
    private var thumbnailSize: CGSize = .zero
    private var lastKnownThumbnailRange: CMTimeRange = .zero
    private var thumbnails = Array<Thumbnail>()
    private var generator: AVAssetImageGenerator?
    
    private var impactFeedbackGenerator: UIImpactFeedbackGenerator?
    private var didClampWhilePanning = false
    
    
    // MARK: - Private
    private func setup() {
        addSubview(thumbnailClipView)
        thumbnailClipView.addSubview(thumbnailWrapperView)
        thumbnailWrapperView.addSubview(leadingThumbRest)
        thumbnailWrapperView.addSubview(trailingThumbRest)
        thumbnailWrapperView.addSubview(thumbnailTrackView)
        thumbnailWrapperView.addSubview(thumbnailLeadingCoverView)
        thumbnailWrapperView.addSubview(thumbnailTrailingCoverView)
        
        progressIndicator.backgroundColor = .white
        progressIndicator.layer.shadowColor = UIColor.black.cgColor
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
        thumbnailLeadingCoverView.backgroundColor = UIColor(white: 0, alpha: 0.75)
        thumbnailTrailingCoverView.backgroundColor = UIColor(white: 0, alpha: 0.75)
        
        leadingThumbRest.backgroundColor = thumbRestColor
        trailingThumbRest.backgroundColor = thumbRestColor
        
        thumbnailWrapperView.backgroundColor = trackBackgroundColor
        thumbnailWrapperView.layer.cornerRadius = 6
        thumbnailWrapperView.layer.cornerCurve = .continuous
        
        leadingThumbRest.layer.cornerRadius = 6
        leadingThumbRest.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
        leadingThumbRest.layer.cornerCurve = .continuous
        
        trailingThumbRest.layer.cornerRadius = 6
        trailingThumbRest.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
        trailingThumbRest.layer.cornerCurve = .continuous
        
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = .zero
        shadowView.layer.shadowRadius = 2
        shadowView.layer.shadowOpacity = 0.25
        
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
        
        thumbnailInteractionGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(thumbnailPanned(_:)))
        thumbnailInteractionGestureRecognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
        thumbnailInteractionGestureRecognizer.minimumPressDuration = 0
        thumbnailInteractionGestureRecognizer.require(toFail: leadingGestureRecognizer)
        thumbnailInteractionGestureRecognizer.require(toFail: trailingGestureRecognizer)
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
        
        var seenIndex = 0
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, cgImage, actualTime, result, error in
            DispatchQueue.main.async {
                seenIndex += 1
                
                guard let cgImage = cgImage else {return}
                let image = UIImage(cgImage: cgImage)
                
                let imageView = newThumbnails[seenIndex - 1].imageView
                UIView.transition(with: imageView, duration: 0.25, options: [.transitionCrossDissolve], animations: {
                    imageView.image = image
                })
            }
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
        let newDuration = CGFloat(range.duration.seconds > 4 ?  2.0 : range.duration.seconds * 0.5)
        
        let durationTime = CMTime(seconds: Double(newDuration), preferredTimescale: 600)
        
        if trimmingState == .leading {
            let position = locationForTime(selectedRange.start) - inset
            let start = position / availableWidth * newDuration
            zoomedInRange = CMTimeRange(start: CMTimeSubtract(selectedRange.start, CMTime(seconds: Double(start), preferredTimescale: 600)), duration: durationTime)
        } else {
            let position = locationForTime(selectedRange.end) - inset
            
            let durationToStart = position / availableWidth * newDuration
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
            progressIndicator.alpha = (trimmingState == .none ? 1 : 0)
            progressIndicatorControl.isUserInteractionEnabled = (trimmingState == .none)
            if trimmingState == .none {
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