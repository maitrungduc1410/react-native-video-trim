//
//  VideoTrimmerViewController.swift
//  VideoTrim
//
//  Created by Duc Trung Mai on 20/5/25.
//

import UIKit
import AVKit
import React

extension CMTime {
    var displayString: String {
        let offset = TimeInterval(seconds)
        let numberOfNanosecondsFloat = (offset - TimeInterval(Int(offset))) * 100.0
        let nanoseconds = Int(numberOfNanosecondsFloat)
        
        let formatter = CMTime.dateFormatter
        return String(format: "%@.%02d", formatter.string(from: offset) ?? "00:00", nanoseconds)
    }
    
    private static var dateFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return formatter
    }()
}

@available(iOS 13.0, *)
class VideoTrimmerViewController: UIViewController {
    var asset: AVAsset? {
        didSet {
            if let _ = asset {
                setupVideoTrimmer()
                setupPlayerController()
                setupTimeObserver()
                updateLabels()
            }
        }
    }
    private var maximumDuration: Int?
    private var minimumDuration: Int?
    private var cancelButtonText = "Cancel"
    private var saveButtonText = "Save"
    var cancelBtnClicked: (() -> Void)?
    var saveBtnClicked: ((CMTimeRange) -> Void)?
    private var enableHapticFeedback = true
    private var zoomOnWaitingDuration: Double = 5.0 // Default: 5 seconds
    
    private var trimmerColor: UIColor = UIColor.systemYellow
    private var handleIconColor: UIColor = UIColor.black
    private var isLightTheme = false
    private var waveformBarColor: UIColor = .white
    private var waveformBgColor: UIColor = UIColor(red: 0.204, green: 0.471, blue: 0.965, alpha: 1)
    private var waveformBarWidth: CGFloat = 3
    private var waveformBarGap: CGFloat = 2
    private var waveformBarCornerRadius: CGFloat = 1.5
    private var iconColor: UIColor { isLightTheme ? .black : .white }
    private var dimmedIconColor: UIColor { iconColor.withAlphaComponent(0.5) }
    private let symbolConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    private let speedOptions: [Double] = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0]
    
    private let playerController = AVPlayerViewController()
    private var trimmer: VideoTrimmer!
    private var timingStackView: UIStackView!
    private var leadingTrimLabel: UILabel!
    private var currentTimeLabel: UILabel!
    private var trailingTrimLabel: UILabel!
    private var btnStackView: UIStackView!
    private var cancelBtn: UIButton!
    private var playBtn: UIButton!
    private let loadingIndicator = UIActivityIndicatorView()
    private var saveBtn: UIButton!
    private let playIcon = UIImage(systemName: "play.fill")
    private let pauseIcon = UIImage(systemName: "pause.fill")
    private let audioBannerView = UIImage(systemName: "airpodsmax")
    private var player: AVPlayer! { playerController.player }
    private var timeObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var autoplay = false
    private var jumpToPositionOnLoad: Double = 0;
    private var headerText: String?
    private var headerTextSize = 16
    private var headerTextColor: Double?
    private var headerView: UIView?
    
    private(set) var rotationCount = 0
    private(set) var isFlipped = false
    private(set) var isMuted = false
    private var muteBtn: UIButton?
    private(set) var speed: Double = 1.0
    private var speedBtn: UIButton?
    private var isVideoType = true
    private var playerContainerView: UIView!
    private var transformStackView: UIStackView?
    
    private var cropBtn: UIButton?
    private var cropOverlayView: CropOverlayView?
    private(set) var isCropActive = false
    
    private struct TransformSnapshot: Equatable {
        let rotationCount: Int
        let isFlipped: Bool
        let isCropActive: Bool
        let cropNormalized: CGRect?
    }
    private var undoStack: [TransformSnapshot] = []
    private var redoStack: [TransformSnapshot] = []
    private var undoBtn: UIButton?
    private var redoBtn: UIButton?
    private var preCropSnapshot: TransformSnapshot?
    
    
    var isSeekInProgress: Bool = false  // Marker
    private var chaseTime = CMTime.zero
    private var preferredFrameRate: Float = 23.98
    
    public func onAssetFailToLoad() {
        loadingIndicator.stopAnimating()
        btnStackView.removeArrangedSubview(loadingIndicator)
        loadingIndicator.removeFromSuperview()
        
        let imageViewContainer = UIView()
        let imageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        imageView.tintColor = .systemYellow
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        imageViewContainer.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 36),
            imageView.heightAnchor.constraint(equalToConstant: 36),
            imageView.centerXAnchor.constraint(equalTo: imageViewContainer.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: imageViewContainer.centerYAnchor)
        ])
        imageViewContainer.alpha = 0
        
        btnStackView.insertArrangedSubview(imageViewContainer, at: 1)
        
        UIView.animate(withDuration: 0.25, animations: {
            imageViewContainer.alpha = 1
        })
    }
    
    // MARK: - Input
    @objc private func didBeginTrimmingFromStart(_ sender: VideoTrimmer) {
        handleBeforeProgressChange()
    }
    
    @objc private func leadingGrabberChanged(_ sender: VideoTrimmer) {
        handleProgressChanged(time: trimmer.selectedRange.start)
    }
    
    @objc private func didEndTrimmingFromStart(_ sender: VideoTrimmer) {
        handleTrimmingEnd(true)
    }
    
    @objc private func didBeginTrimmingFromEnd(_ sender: VideoTrimmer) {
        handleBeforeProgressChange()
    }
    
    @objc private func trailingGrabberChanged(_ sender: VideoTrimmer) {
        handleProgressChanged(time: trimmer.selectedRange.end)
    }
    
    @objc private func didEndTrimmingFromEnd(_ sender: VideoTrimmer) {
        handleTrimmingEnd(false)
    }
    
    @objc private func didBeginDraggingRange(_ sender: VideoTrimmer) {
        handleBeforeProgressChange()
    }
    
    @objc private func rangeDragChanged(_ sender: VideoTrimmer) {
        handleProgressChanged(time: trimmer.selectedRange.start)
    }
    
    @objc private func didEndDraggingRange(_ sender: VideoTrimmer) {
        self.trimmer.progress = trimmer.selectedRange.start
        updateLabels()
        seek(to: trimmer.progress)
    }
    
    @objc private func didBeginScrubbing(_ sender: VideoTrimmer) {
        handleBeforeProgressChange()
    }
    
    @objc private func didEndScrubbing(_ sender: VideoTrimmer) {
        updateLabels()
    }
    
    @objc private func progressDidChanged(_ sender: VideoTrimmer) {
        handleProgressChanged(time: trimmer.progress)
    }
    
    // MARK: - Private
    private func updateLabels() {
        leadingTrimLabel.text = trimmer.selectedRange.start.displayString
        currentTimeLabel.text = trimmer.progress.displayString
        trailingTrimLabel.text = trimmer.selectedRange.end.displayString
    }
    
    private func handleBeforeProgressChange() {
        updateLabels()
        player.pause()
        setPlayBtnIcon()
    }
    
    private func handleProgressChanged(time: CMTime) {
        updateLabels()
        seek(to: time)
    }
    
    private func handleTrimmingEnd(_ start: Bool) {
        self.trimmer.progress = start ? trimmer.selectedRange.start : trimmer.selectedRange.end
        updateLabels()
        seek(to: trimmer.progress)
    }
    
    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupButtons()
        setupTimeLabels()
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc private func appWillResignActive() {
        guard asset != nil else { return }
        player.pause()
        setPlayBtnIcon()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // if asset has been initialized
        guard let _ = asset else { return }
        player.pause()
        
        statusObservation?.invalidate()
        statusObservation = nil
        
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        
        playerController.player = nil
        playerController.dismiss(animated: false, completion: nil)
        
        // Setting asset to nil triggers VideoTrimmer.asset.didSet, which
        // cancels all in-flight work (thumbnail generation, waveform reader,
        // audio download) and deletes temporary files.
        trimmer?.asset = nil
    }
    
    public func pausePlayer() {
        player.pause()
        setPlayBtnIcon()
    }
    
    @objc private func togglePlay(sender: UIButton) {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            if CMTimeCompare(trimmer.progress, trimmer.selectedRange.end) != -1 {
                trimmer.progress = trimmer.selectedRange.start
                self.seek(to: trimmer.progress)
            }
            
            player.play()
            player.rate = Float(speed)
        }
        
        setPlayBtnIcon()
    }
    
    @objc private func onSaveBtnClicked() {
        saveBtnClicked?(trimmer.selectedRange)
    }
    
    @objc private func onCancelBtnClicked() {
        cancelBtnClicked?()
    }
    
    // MARK: - Color Update Methods
    private func applyTrimmerColors() {
        guard let trimmer = trimmer else { return }
        
        // Apply trimmer color to the thumb view
        trimmer.thumbView.updateTrimmerColor(trimmerColor)
        
        // Apply handle icon color to the chevron image views
        trimmer.thumbView.updateHandleIconColor(handleIconColor)
    }
    
    // MARK: - Setup Methods
    private func setupView() {
        self.overrideUserInterfaceStyle = isLightTheme ? .light : .dark
        view.backgroundColor = isLightTheme ? .white : .black
        
        if let headerText = headerText {
            headerView = UIView()
            headerView!.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(headerView!)
            let scrollView = UIScrollView()
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            headerView!.addSubview(scrollView)
            
            let headerLabel = UILabel()
            headerLabel.text = headerText
            headerLabel.textAlignment = .center
            headerLabel.textColor = RCTConvert.uiColor(headerTextColor)
            headerLabel.font = UIFont.systemFont(ofSize: CGFloat(headerTextSize))
            headerLabel.numberOfLines = 1
            headerLabel.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(headerLabel)
            
            NSLayoutConstraint.activate([
                headerView!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                headerView!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                headerView!.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                
                scrollView.topAnchor.constraint(equalTo: headerView!.topAnchor, constant: 6),
                scrollView.bottomAnchor.constraint(equalTo: headerView!.bottomAnchor, constant: -2),
                scrollView.leadingAnchor.constraint(equalTo: headerView!.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: headerView!.trailingAnchor),
                scrollView.heightAnchor.constraint(equalTo: headerLabel.heightAnchor),
                
                headerLabel.topAnchor.constraint(equalTo: scrollView.topAnchor),
                headerLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                headerLabel.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.leadingAnchor, constant: 16),
                headerLabel.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.trailingAnchor, constant: -16),
            ])
            
            let centerX = headerLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor)
            centerX.priority = .defaultHigh
            let minWidth = headerLabel.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.widthAnchor, constant: -32)
            minWidth.priority = .defaultLow
            NSLayoutConstraint.activate([centerX, minWidth])
            
            view.layoutIfNeeded() // layout after activate constraints, otherwise headerView height = screen height, which leads to playerViewController is missing at runtime
        }
    }
    
    private func setupButtons() {
        cancelBtn = UIButton.createButton(title: cancelButtonText, font: .systemFont(ofSize: 18), titleColor: iconColor, target: self, action: #selector(onCancelBtnClicked))
        playBtn = UIButton.createButton(image: playIcon, tintColor: iconColor, target: self, action: #selector(togglePlay(sender:)))
        playBtn.alpha = 0
        playBtn.isEnabled = false
        
        saveBtn = UIButton.createButton(title: saveButtonText, font: .systemFont(ofSize: 18), titleColor: .systemBlue, target: self, action: #selector(onSaveBtnClicked))
        saveBtn.alpha = 0
        saveBtn.isEnabled = false
        
        btnStackView = UIStackView(arrangedSubviews: [cancelBtn, loadingIndicator, saveBtn])
        btnStackView.axis = .horizontal
        btnStackView.alignment = .center
        btnStackView.distribution = .fillEqually
        btnStackView.spacing = UIStackView.spacingUseSystem
        btnStackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(btnStackView)
        
        NSLayoutConstraint.activate([
            btnStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            btnStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            btnStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        loadingIndicator.startAnimating()
    }
    
    private func setupTimeLabels() {
        let labelColor = isLightTheme ? UIColor.black : UIColor.white
        leadingTrimLabel = UILabel.createLabel(textAlignment: .left, textColor: labelColor)
        leadingTrimLabel.text = "00:00.000"
        currentTimeLabel = UILabel.createLabel(textAlignment: .center, textColor: labelColor)
        currentTimeLabel.text = "00:00.000"
        trailingTrimLabel = UILabel.createLabel(textAlignment: .right, textColor: labelColor)
        trailingTrimLabel.text = "00:00.000"
        
        timingStackView = UIStackView(arrangedSubviews: [leadingTrimLabel, currentTimeLabel, trailingTrimLabel])
        timingStackView.axis = .horizontal
        timingStackView.alignment = .fill
        timingStackView.distribution = .fillEqually
        timingStackView.spacing = UIStackView.spacingUseSystem
        view.addSubview(timingStackView)
        timingStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timingStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            timingStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            timingStackView.bottomAnchor.constraint(equalTo: btnStackView.topAnchor, constant: -8)
        ])
    }
    
    private func setupVideoTrimmer() {
        trimmer = VideoTrimmer()
        trimmer.isLightTheme = isLightTheme
        trimmer.waveformBarColor = waveformBarColor
        trimmer.waveformBgColor = waveformBgColor
        trimmer.waveformBarWidth = waveformBarWidth
        trimmer.waveformBarGap = waveformBarGap
        trimmer.waveformBarCornerRadius = waveformBarCornerRadius
        trimmer.isAudioOnly = !isVideoType
        trimmer.asset = asset
        trimmer.minimumDuration = CMTime(seconds: 1, preferredTimescale: 600)
        trimmer.enableHapticFeedback = enableHapticFeedback
        trimmer.zoomOnWaitingDuration = zoomOnWaitingDuration
        
        if let maxDuration = maximumDuration {
            trimmer.maximumDuration = CMTime(seconds: max(1, Double(maxDuration) / 1000.0), preferredTimescale: 600)
            if trimmer.maximumDuration > asset!.duration {
                trimmer.maximumDuration = asset!.duration
            }
            trimmer.selectedRange = CMTimeRange(start: .zero, end: trimmer.maximumDuration)
        }
        
        if let minDuration = minimumDuration {
            trimmer.minimumDuration = CMTime(seconds: max(1, Double(minDuration) / 1000.0), preferredTimescale: 600)
        }
        
        trimmer.addTarget(self, action: #selector(didBeginScrubbing(_:)), for: VideoTrimmer.didBeginScrubbing)
        trimmer.addTarget(self, action: #selector(didEndScrubbing(_:)), for: VideoTrimmer.didEndScrubbing)
        trimmer.addTarget(self, action: #selector(progressDidChanged(_:)), for: VideoTrimmer.progressChanged)
        
        trimmer.addTarget(self, action: #selector(didBeginTrimmingFromStart(_:)), for: VideoTrimmer.didBeginTrimmingFromStart)
        trimmer.addTarget(self, action: #selector(leadingGrabberChanged(_:)), for: VideoTrimmer.leadingGrabberChanged)
        trimmer.addTarget(self, action: #selector(didEndTrimmingFromStart(_:)), for: VideoTrimmer.didEndTrimmingFromStart)
        
        trimmer.addTarget(self, action: #selector(didBeginTrimmingFromEnd(_:)), for: VideoTrimmer.didBeginTrimmingFromEnd)
        trimmer.addTarget(self, action: #selector(trailingGrabberChanged(_:)), for: VideoTrimmer.trailingGrabberChanged)
        trimmer.addTarget(self, action: #selector(didEndTrimmingFromEnd(_:)), for: VideoTrimmer.didEndTrimmingFromEnd)
        
        trimmer.addTarget(self, action: #selector(didBeginDraggingRange(_:)), for: VideoTrimmer.didBeginDraggingRange)
        trimmer.addTarget(self, action: #selector(rangeDragChanged(_:)), for: VideoTrimmer.rangeDragChanged)
        trimmer.addTarget(self, action: #selector(didEndDraggingRange(_:)), for: VideoTrimmer.didEndDraggingRange)
        trimmer.alpha = 0
        view.addSubview(trimmer)
        trimmer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            trimmer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            trimmer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            trimmer.bottomAnchor.constraint(equalTo: timingStackView.topAnchor, constant: -16),
            trimmer.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        UIView.animate(withDuration: 0.25, animations: {
            self.trimmer.alpha = 1
        })
        
        // Apply the trimmer colors
        applyTrimmerColors()
    }
    
    private func setupPlayerController() {
        guard let asset = asset else { return }
        playerController.showsPlaybackControls = false
        if #available(iOS 16.0, *) {
            playerController.allowsVideoFrameAnalysis = false
        }
        playerController.player = AVPlayer()
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        player.isMuted = isMuted
        
        statusObservation = player.observe(\.status, options: [.new, .initial]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.onPlayerReady()
            }
        }
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        
        setupTransformButtons()
        
        let topAnchor: NSLayoutYAxisAnchor
        if let transformStack = transformStackView {
            topAnchor = transformStack.bottomAnchor
        } else if let headerView = headerView {
            topAnchor = headerView.bottomAnchor
        } else {
            topAnchor = view.safeAreaLayoutGuide.topAnchor
        }
        
        playerContainerView = UIView()
        playerContainerView.clipsToBounds = true
        view.addSubview(playerContainerView)
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerContainerView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            playerContainerView.bottomAnchor.constraint(equalTo: trimmer.topAnchor, constant: -16)
        ])
        
        addChild(playerController)
        playerContainerView.addSubview(playerController.view)
        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        playerController.view.backgroundColor = .clear
        
        let bracketInset: CGFloat = 5
        NSLayoutConstraint.activate([
            playerController.view.topAnchor.constraint(equalTo: playerContainerView.topAnchor, constant: bracketInset),
            playerController.view.bottomAnchor.constraint(equalTo: playerContainerView.bottomAnchor, constant: -bracketInset),
            playerController.view.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor, constant: bracketInset),
            playerController.view.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor, constant: -bracketInset),
        ])
        
        // Add observer for the end of playback
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    @objc private func playerDidFinishPlaying(note: NSNotification) {
        // Directly set the play icon
        // the reason in at this time player.timeControlStatus == .playing still returns true
        playBtn.setImage(self.playIcon, for: .normal)
    }
    
    // MARK: - Transform (Rotation/Flip/Crop) + Undo/Redo
    private func setupTransformButtons() {
        guard isVideoType else { return }
        
        let flipBtn = UIButton(type: .system)
        flipBtn.setImage(UIImage(systemName: "arrow.trianglehead.left.and.right.righttriangle.left.righttriangle.right", withConfiguration: symbolConfig), for: .normal)
        flipBtn.tintColor = iconColor
        flipBtn.addTarget(self, action: #selector(onFlipTapped), for: .touchUpInside)
        
        let rotateBtn = UIButton(type: .system)
        rotateBtn.setImage(UIImage(systemName: "rotate.left", withConfiguration: symbolConfig), for: .normal)
        rotateBtn.tintColor = iconColor
        rotateBtn.addTarget(self, action: #selector(onRotateTapped), for: .touchUpInside)
        
        let cropButton = UIButton(type: .system)
        cropButton.setImage(UIImage(systemName: "crop", withConfiguration: symbolConfig), for: .normal)
        cropButton.tintColor = dimmedIconColor
        cropButton.addTarget(self, action: #selector(onCropTapped), for: .touchUpInside)
        self.cropBtn = cropButton
        
        let muteButton = UIButton(type: .system)
        muteButton.setImage(UIImage(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", withConfiguration: symbolConfig), for: .normal)
        muteButton.tintColor = iconColor
        muteButton.addTarget(self, action: #selector(onMuteTapped), for: .touchUpInside)
        self.muteBtn = muteButton
        
        let speedButton = UIButton(type: .system)
        let speedLabel = speed == 1.0 ? "1x" : "\(speed)x"
        speedButton.setTitle(speedLabel, for: .normal)
        speedButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        speedButton.tintColor = iconColor
        if #available(iOS 14.0, *) {
            speedButton.showsMenuAsPrimaryAction = true
            speedButton.menu = buildSpeedMenu()
        } else {
            speedButton.addTarget(self, action: #selector(onSpeedTapped), for: .touchUpInside)
        }
        self.speedBtn = speedButton
        
        let undoButton = UIButton(type: .system)
        undoButton.setImage(UIImage(systemName: "arrow.uturn.backward", withConfiguration: symbolConfig), for: .normal)
        undoButton.tintColor = dimmedIconColor
        undoButton.isEnabled = false
        undoButton.addTarget(self, action: #selector(onUndoTapped), for: .touchUpInside)
        self.undoBtn = undoButton
        
        let redoButton = UIButton(type: .system)
        redoButton.setImage(UIImage(systemName: "arrow.uturn.forward", withConfiguration: symbolConfig), for: .normal)
        redoButton.tintColor = dimmedIconColor
        redoButton.isEnabled = false
        redoButton.addTarget(self, action: #selector(onRedoTapped), for: .touchUpInside)
        self.redoBtn = redoButton
        
        let leftStack = UIStackView(arrangedSubviews: [flipBtn, rotateBtn, cropButton, muteButton, speedButton])
        leftStack.axis = .horizontal
        leftStack.spacing = 12
        
        let rightStack = UIStackView(arrangedSubviews: [undoButton, redoButton])
        rightStack.axis = .horizontal
        rightStack.spacing = 12
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let fullRow = UIStackView(arrangedSubviews: [leftStack, spacer, rightStack])
        fullRow.axis = .horizontal
        fullRow.translatesAutoresizingMaskIntoConstraints = false
        fullRow.alpha = 0
        
        view.addSubview(fullRow)
        let btnSize: CGFloat = 28
        NSLayoutConstraint.activate([
            flipBtn.widthAnchor.constraint(equalToConstant: btnSize),
            flipBtn.heightAnchor.constraint(equalToConstant: btnSize),
            rotateBtn.widthAnchor.constraint(equalToConstant: btnSize),
            rotateBtn.heightAnchor.constraint(equalToConstant: btnSize),
            cropButton.widthAnchor.constraint(equalToConstant: btnSize),
            cropButton.heightAnchor.constraint(equalToConstant: btnSize),
            muteButton.widthAnchor.constraint(equalToConstant: btnSize),
            muteButton.heightAnchor.constraint(equalToConstant: btnSize),
            speedButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),
            speedButton.heightAnchor.constraint(equalToConstant: btnSize),
            undoButton.widthAnchor.constraint(equalToConstant: btnSize),
            undoButton.heightAnchor.constraint(equalToConstant: btnSize),
            redoButton.widthAnchor.constraint(equalToConstant: btnSize),
            redoButton.heightAnchor.constraint(equalToConstant: btnSize),
            fullRow.topAnchor.constraint(equalTo: headerView != nil ? headerView!.bottomAnchor : view.safeAreaLayoutGuide.topAnchor, constant: 4),
            fullRow.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            fullRow.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
        
        self.transformStackView = fullRow
    }
    
    @objc private func onMuteTapped() {
        isMuted.toggle()
        muteBtn?.setImage(UIImage(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", withConfiguration: symbolConfig), for: .normal)
        player.isMuted = isMuted
        if enableHapticFeedback {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    // Builds a native context menu for speed selection (iOS 14+). The menu is
    // attached via showsMenuAsPrimaryAction so it opens on tap without an extra
    // long-press gesture. Falls back to UIAlertController on older iOS versions.
    @available(iOS 14.0, *)
    private func buildSpeedMenu() -> UIMenu {
        let actions = speedOptions.map { opt in
            let title = opt == 1.0 ? "Normal (1x)" : "\(opt)x"
            let isSelected = abs(opt - speed) < 0.0001
            return UIAction(title: title, state: isSelected ? .on : .off) { [weak self] _ in
                self?.setSpeed(opt)
            }
        }
        return UIMenu(title: "", children: actions)
    }

    /// Fallback for iOS < 14 where UIMenu is unavailable.
    @objc private func onSpeedTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.overrideUserInterfaceStyle = isLightTheme ? .light : .dark
        for opt in speedOptions {
            let title = opt == 1.0 ? "Normal (1x)" : "\(opt)x"
            let isSelected = abs(opt - speed) < 0.0001
            let action = UIAlertAction(title: title, style: isSelected ? .destructive : .default) { [weak self] _ in
                self?.setSpeed(opt)
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController, let btn = speedBtn {
            pop.sourceView = btn
            pop.sourceRect = btn.bounds
        }
        present(alert, animated: true)
    }
    
    private func setSpeed(_ newSpeed: Double) {
        speed = newSpeed
        let label = newSpeed == 1.0 ? "1x" : "\(newSpeed)x"
        speedBtn?.setTitle(label, for: .normal)
        if #available(iOS 14.0, *) {
            speedBtn?.menu = buildSpeedMenu()
        }
        player.rate = Float(newSpeed)
        if player.timeControlStatus != .playing {
            player.pause()
        }
        if enableHapticFeedback {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    @objc private func onFlipTapped() {
        pushUndo()
        isFlipped.toggle()
        if enableHapticFeedback {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        updateVideoTransform(resetCrop: true)
    }
    
    @objc private func onRotateTapped() {
        pushUndo()
        if isFlipped {
            rotationCount = (rotationCount - 1 + 4) % 4
        } else {
            rotationCount = (rotationCount + 1) % 4
        }
        if enableHapticFeedback {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        updateVideoTransform(resetCrop: true)
    }
    
    private func buildVideoTransform() -> CGAffineTransform {
        let angle = -CGFloat(rotationCount) * (.pi / 2)
        var transform = CGAffineTransform.identity
        if isFlipped {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        transform = transform.rotated(by: angle)
        if rotationCount % 2 != 0 {
            let pvBounds = playerController.view.bounds
            let cBounds = playerContainerView.bounds
            if pvBounds.width > 0 && pvBounds.height > 0 && cBounds.width > 0 && cBounds.height > 0 {
                var videoW = pvBounds.width
                var videoH = pvBounds.height
                if let track = asset?.tracks(withMediaType: .video).first {
                    let raw = track.naturalSize
                    let pt = track.preferredTransform
                    let a = atan2(pt.b, pt.a)
                    let srcRotated = abs(a - .pi / 2) < 0.1 || abs(a + .pi / 2) < 0.1
                    let ds = srcRotated ? CGSize(width: raw.height, height: raw.width) : raw
                    if ds.width > 0 && ds.height > 0 {
                        let videoAR = ds.width / ds.height
                        let viewAR = pvBounds.width / pvBounds.height
                        if videoAR > viewAR {
                            videoW = pvBounds.width
                            videoH = pvBounds.width / videoAR
                        } else {
                            videoH = pvBounds.height
                            videoW = pvBounds.height * videoAR
                        }
                    }
                }
                let bracketMargin: CGFloat = 5
                let availW = cBounds.width - 2 * bracketMargin
                let availH = cBounds.height - 2 * bracketMargin
                let fitScale = min(availW / videoH, availH / videoW)
                transform = transform.scaledBy(x: fitScale, y: fitScale)
            }
        }
        return transform
    }
    
    private func updateVideoTransform(resetCrop: Bool = false) {
        let transform = buildVideoTransform()
        if isCropActive {
            UIView.animate(withDuration: 0.15) {
                self.cropOverlayView?.alpha = 0
            }
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
            self.playerController.view.transform = transform
        } completion: { _ in
            if resetCrop && self.isCropActive {
                self.updateCropAllowedRect()
                self.cropOverlayView?.resetCrop()
                UIView.animate(withDuration: 0.15) {
                    self.cropOverlayView?.alpha = 1
                }
            }
        }
    }
    
    // MARK: - Undo / Redo
    
    private func currentSnapshot() -> TransformSnapshot {
        TransformSnapshot(
            rotationCount: rotationCount,
            isFlipped: isFlipped,
            isCropActive: isCropActive,
            cropNormalized: cropNormalizedRect
        )
    }
    
    private func pushUndo() {
        undoStack.append(currentSnapshot())
        redoStack.removeAll()
        updateUndoRedoButtons()
    }
    
    @objc private func onUndoTapped() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        applySnapshot(prev)
        updateUndoRedoButtons()
    }
    
    @objc private func onRedoTapped() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        applySnapshot(next)
        updateUndoRedoButtons()
    }
    
    private func applySnapshot(_ snap: TransformSnapshot) {
        rotationCount = snap.rotationCount
        isFlipped = snap.isFlipped
        
        let transform = buildVideoTransform()
        
        let wasActive = isCropActive
        isCropActive = snap.isCropActive
        cropBtn?.tintColor = isCropActive ? iconColor : dimmedIconColor
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
            self.playerController.view.transform = transform
        } completion: { _ in
            if self.isCropActive {
                self.showCropOverlayImmediate()
                self.updateCropAllowedRect()
                if let norm = snap.cropNormalized {
                    self.setCropFromNormalized(norm)
                } else {
                    self.cropOverlayView?.resetCrop()
                }
            } else if wasActive {
                self.cropOverlayView?.isHidden = true
                self.cropOverlayView?.alpha = 0
            }
        }
    }
    
    private func setCropFromNormalized(_ norm: CGRect) {
        let vr = getVideoDisplayRectInContainer()
        guard vr.width > 1, vr.height > 1 else { return }
        cropOverlayView?.cropRect = CGRect(
            x: vr.minX + norm.origin.x * vr.width,
            y: vr.minY + norm.origin.y * vr.height,
            width: norm.size.width * vr.width,
            height: norm.size.height * vr.height
        )
    }
    
    private func updateUndoRedoButtons() {
        undoBtn?.tintColor = undoStack.isEmpty ? dimmedIconColor : iconColor
        undoBtn?.isEnabled = !undoStack.isEmpty
        redoBtn?.tintColor = redoStack.isEmpty ? dimmedIconColor : iconColor
        redoBtn?.isEnabled = !redoStack.isEmpty
    }
    
    // MARK: - Crop
    
    @objc private func onCropTapped() {
        isCropActive.toggle()
        cropBtn?.tintColor = isCropActive ? iconColor : dimmedIconColor
        
        if enableHapticFeedback {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        if isCropActive {
            showCropOverlay()
        } else {
            hideCropOverlay()
        }
    }
    
    private func showCropOverlay() {
        if let existing = cropOverlayView {
            existing.isHidden = false
            existing.alpha = 0
            playerContainerView.layoutIfNeeded()
            updateCropAllowedRect()
            UIView.animate(withDuration: 0.2) { existing.alpha = 1 }
            return
        }
        
        createCropOverlay()
        playerContainerView.layoutIfNeeded()
        updateCropAllowedRect()
        UIView.animate(withDuration: 0.2) { self.cropOverlayView?.alpha = 1 }
    }
    
    private func showCropOverlayImmediate() {
        if let existing = cropOverlayView {
            existing.isHidden = false
            existing.alpha = 1
            return
        }
        createCropOverlay()
        cropOverlayView?.alpha = 1
    }
    
    private func createCropOverlay() {
        let overlay = CropOverlayView()
        overlay.isLightTheme = isLightTheme
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.alpha = 0
        playerContainerView.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: playerContainerView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: playerContainerView.bottomAnchor),
        ])
        cropOverlayView = overlay
        
        overlay.onCropBegan = { [weak self] in
            self?.preCropSnapshot = self?.currentSnapshot()
        }
        overlay.onCropEnded = { [weak self] in
            guard let self = self, let snap = self.preCropSnapshot else { return }
            if self.currentSnapshot() != snap {
                self.undoStack.append(snap)
                self.redoStack.removeAll()
                self.updateUndoRedoButtons()
            }
            self.preCropSnapshot = nil
        }
    }
    
    private func hideCropOverlay() {
        guard let overlay = cropOverlayView else { return }
        UIView.animate(withDuration: 0.2, animations: {
            overlay.alpha = 0
        }) { _ in
            overlay.isHidden = true
        }
    }
    
    private func updateCropAllowedRect() {
        guard let overlay = cropOverlayView else { return }
        overlay.allowedRect = getVideoDisplayRectInContainer()
    }
    
    func getVideoDisplayRectInContainer() -> CGRect {
        guard let containerView = playerContainerView,
              let asset = asset,
              let track = asset.tracks(withMediaType: .video).first else {
            return playerContainerView?.bounds ?? .zero
        }
        
        let raw = track.naturalSize
        let pt = track.preferredTransform
        let angle = atan2(pt.b, pt.a)
        let isSourceRotated = abs(angle - .pi / 2) < 0.1 || abs(angle + .pi / 2) < 0.1
        let displayedSize = isSourceRotated
            ? CGSize(width: raw.height, height: raw.width)
            : raw
        
        let pvBounds = playerController.view.bounds
        guard pvBounds.width > 0, pvBounds.height > 0,
              displayedSize.width > 0, displayedSize.height > 0 else {
            return containerView.bounds
        }
        
        let videoAR = displayedSize.width / displayedSize.height
        let viewAR = pvBounds.width / pvBounds.height
        
        var videoRect: CGRect
        if videoAR > viewAR {
            let h = pvBounds.width / videoAR
            videoRect = CGRect(x: 0, y: (pvBounds.height - h) / 2,
                               width: pvBounds.width, height: h)
        } else {
            let w = pvBounds.height * videoAR
            videoRect = CGRect(x: (pvBounds.width - w) / 2, y: 0,
                               width: w, height: pvBounds.height)
        }
        
        return playerController.view.convert(videoRect, to: containerView)
    }
    
    var cropNormalizedRect: CGRect? {
        guard isCropActive,
              let overlay = cropOverlayView, !overlay.isHidden else { return nil }
        
        let videoRect = getVideoDisplayRectInContainer()
        guard videoRect.width > 1, videoRect.height > 1 else { return nil }
        
        let cr = overlay.cropRect
        let nx = (cr.minX - videoRect.minX) / videoRect.width
        let ny = (cr.minY - videoRect.minY) / videoRect.height
        let nw = cr.width / videoRect.width
        let nh = cr.height / videoRect.height
        
        if nx < 0.01 && ny < 0.01 && nw > 0.99 && nh > 0.99 {
            return nil
        }
        
        return CGRect(
            x: max(0, min(1, nx)),
            y: max(0, min(1, ny)),
            width: max(0, min(1, nw)),
            height: max(0, min(1, nh))
        )
    }
    
    private func setupTimeObserver() {
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            if self.player.timeControlStatus != .playing {
                return
            }
            
            self.trimmer.progress = time
            
            // pause if reach end of selected range
            if CMTimeCompare(self.trimmer.progress, trimmer.selectedRange.end) == 1 {
                player.pause()
                self.trimmer.progress = trimmer.selectedRange.end
                self.seek(to: trimmer.selectedRange.end)
            }
            
            currentTimeLabel.text = trimmer.progress.displayString
            
            self.setPlayBtnIcon()
        }
    }
    
    private func setPlayBtnIcon() {
        self.playBtn.setImage(self.player.timeControlStatus == .playing ? self.pauseIcon : self.playIcon, for: .normal)
    }
    
    // ====Smoother seek
    public func seek(to time: CMTime) {
        seekSmoothlyToTime(newChaseTime: time)
    }
    
    private func seekSmoothlyToTime(newChaseTime: CMTime) {
        if CMTimeCompare(newChaseTime, chaseTime) != 0 {
            chaseTime = newChaseTime
            
            if !isSeekInProgress {
                trySeekToChaseTime()
            }
        }
    }
    
    private func trySeekToChaseTime() {
        guard player?.status == .readyToPlay else { return }
        actuallySeekToTime()
    }
    
    private func actuallySeekToTime() {
        isSeekInProgress = true
        let seekTimeInProgress = chaseTime
        
        player?.seek(to: seekTimeInProgress, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let `self` = self else { return }
            
            if CMTimeCompare(seekTimeInProgress, self.chaseTime) == 0 {
                self.isSeekInProgress = false
            } else {
                self.trySeekToChaseTime()
            }
        }
    }
    
  public func configure(config: NSDictionary) {
    if let maxDuration = config["maxDuration"] as? Int, maxDuration > 0 {
      maximumDuration = maxDuration
    }
    
    if let minDuration = config["minDuration"] as? Int, minDuration > 0 {
      minimumDuration = minDuration
    }
    
    isLightTheme = (config["theme"] as? String) == "light"
    
    cancelButtonText = config["cancelButtonText"] as? String ?? "Cancel"
    saveButtonText = config["saveButtonText"] as? String ?? "Save"
    jumpToPositionOnLoad = config["jumpToPositionOnLoad"] as? Double ?? 0
    enableHapticFeedback = config["enableHapticFeedback"] as? Bool ?? true
    zoomOnWaitingDuration = (config["zoomOnWaitingDuration"] as? Double ?? 5.0) / 1000.0 // convert ms to s
    autoplay = config["autoplay"] as? Bool ?? false
    isVideoType = (config["type"] as? String ?? "video") == "video"
    isMuted = config["removeAudio"] as? Bool ?? false
    if let cfgSpeed = config["speed"] as? Double {
        speed = cfgSpeed
    }
    headerText = config["headerText"] as? String
    headerTextSize = config["headerTextSize"] as? Int ?? 16
    headerTextColor = config["headerTextColor"] as? Double
    
    if let trimmerColorValue = config["trimmerColor"] as? Double {
        trimmerColor = RCTConvert.uiColor(trimmerColorValue) ?? UIColor.systemYellow
    }
    if let handleIconColorValue = config["handleIconColor"] as? Double {
        handleIconColor = RCTConvert.uiColor(handleIconColorValue) ?? (isLightTheme ? .white : .black)
    }
    if let v = config["waveformColor"] as? Double {
        waveformBarColor = RCTConvert.uiColor(v) ?? .white
    }
    if let v = config["waveformBackgroundColor"] as? Double {
        waveformBgColor = RCTConvert.uiColor(v) ?? UIColor(red: 0.204, green: 0.471, blue: 0.965, alpha: 1)
    }
    if let v = config["waveformBarWidth"] as? Double, v > 0 {
        waveformBarWidth = CGFloat(v)
    }
    if let v = config["waveformBarGap"] as? Double, v >= 0 {
        waveformBarGap = CGFloat(v)
    }
    if let v = config["waveformBarCornerRadius"] as? Double, v >= 0 {
        waveformBarCornerRadius = CGFloat(v)
    }
  }
    
    private func onPlayerReady() {
        guard player.status == .readyToPlay else { return }
        
        loadingIndicator.stopAnimating()
        btnStackView.removeArrangedSubview(loadingIndicator)
        loadingIndicator.removeFromSuperview()
        btnStackView.insertArrangedSubview(playBtn, at: 1)
        
        UIView.animate(withDuration: 0.25, animations: {
            self.playBtn.alpha = 1
            self.playBtn.isEnabled = true
            self.saveBtn.alpha = 1
            self.saveBtn.isEnabled = true
            self.transformStackView?.alpha = 1
        })
        
        if jumpToPositionOnLoad > 0 {
            let duration = (asset?.duration.seconds ?? 0) * 1000
            let endMs = trimmer.selectedRange.end.seconds * 1000
            let time = min(jumpToPositionOnLoad, min(duration, endMs))
            let cmtime = CMTime(value: CMTimeValue(time), timescale: 1000)
            
            self.seek(to: cmtime)
            self.trimmer.progress = cmtime
            self.currentTimeLabel.text = self.trimmer.progress.displayString
        }
        
        if autoplay {
            togglePlay(sender: playBtn)
        }
    }
}

private extension UIButton {
    static func createButton(title: String? = nil, image: UIImage? = nil, font: UIFont? = nil, titleColor: UIColor? = nil, tintColor: UIColor? = nil, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        if let title = title {
            button.setTitle(title, for: .normal)
        }
        if let image = image {
            button.setImage(image, for: .normal)
        }
        if let font = font {
            button.titleLabel?.font = font
        }
        if let titleColor = titleColor {
            button.setTitleColor(titleColor, for: .normal)
        }
        if let tintColor = tintColor {
            button.tintColor = tintColor
        }
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
}

private extension UILabel {
    static func createLabel(textAlignment: NSTextAlignment, textColor: UIColor) -> UILabel {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textAlignment = textAlignment
        label.textColor = textColor
        return label
    }
}
