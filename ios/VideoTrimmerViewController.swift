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
    
    // New color properties
    private var trimmerColor: UIColor = UIColor.systemYellow
    private var handleIconColor: UIColor = UIColor.black
    
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
    private var autoplay = false
    private var jumpToPositionOnLoad: Double = 0;
    private var headerText: String?
    private var headerTextSize = 16
    private var headerTextColor: Double?
    private var headerView: UIView?
    
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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // if asset has been initialized
        guard let _ = asset else { return }
        player.pause()
        
        // Clean up the observer
        player.removeObserver(self, forKeyPath: "status")
        
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        // Remove observer
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        
        playerController.player = nil
        playerController.dismiss(animated: false, completion: nil)
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
        self.overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black // need to have this otherwise during animation the background of this VC is still white in white theme
        
        if let headerText = headerText {
            headerView = UIView()
            headerView!.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(headerView!)
            let headerTextView = UITextView()
            headerTextView.text = headerText
            headerTextView.textAlignment = .center
          
          headerTextView.textColor = RCTConvert.uiColor(headerTextColor)
//          UIColor.color(fromHexNumber: headerTextColor as NSNumber?, defaultColor: .white)
          
            headerTextView.font = UIFont.systemFont(ofSize: CGFloat(headerTextSize))  // Set font size here
            headerTextView.translatesAutoresizingMaskIntoConstraints = false
            headerView!.addSubview(headerTextView)
            
            NSLayoutConstraint.activate([
                // HeaderView constraints
                headerView!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                headerView!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                headerView!.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                headerView!.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
                
                // HeaderText constraints
                headerTextView.topAnchor.constraint(equalTo: headerView!.topAnchor),
                headerTextView.bottomAnchor.constraint(equalTo: headerView!.bottomAnchor),
                headerTextView.leadingAnchor.constraint(equalTo: headerView!.leadingAnchor),
                headerTextView.trailingAnchor.constraint(equalTo: headerView!.trailingAnchor),
            ])
            
            view.layoutIfNeeded() // layout after activate constraints, otherwise headerView height = screen height, which leads to playerViewController is missing at runtime
        }
    }
    
    private func setupButtons() {
        cancelBtn = UIButton.createButton(title: cancelButtonText, font: .systemFont(ofSize: 18), titleColor: .white, target: self, action: #selector(onCancelBtnClicked))
        playBtn = UIButton.createButton(image: playIcon, tintColor: .white, target: self, action: #selector(togglePlay(sender:)))
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
        leadingTrimLabel = UILabel.createLabel(textAlignment: .left, textColor: .white)
        leadingTrimLabel.text = "00:00.000"
        currentTimeLabel = UILabel.createLabel(textAlignment: .center, textColor: .white)
        currentTimeLabel.text = "00:00.000"
        trailingTrimLabel = UILabel.createLabel(textAlignment: .right, textColor: .white)
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
        trimmer.asset = asset
        trimmer.minimumDuration = CMTime(seconds: 1, preferredTimescale: 600)
        trimmer.enableHapticFeedback = enableHapticFeedback
        
        if let maxDuration = maximumDuration {
            trimmer.maximumDuration = CMTime(seconds: max(1, Double(maxDuration)), preferredTimescale: 600)
            if trimmer.maximumDuration > asset!.duration {
                trimmer.maximumDuration = asset!.duration
            }
            trimmer.selectedRange = CMTimeRange(start: .zero, end: trimmer.maximumDuration)
        }
        
        if let minDuration = minimumDuration {
            trimmer.minimumDuration = CMTime(seconds: max(1, Double(minDuration)), preferredTimescale: 600)
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
        playerController.showsPlaybackControls = false
        if #available(iOS 16.0, *) {
            playerController.allowsVideoFrameAnalysis = false
        }
        playerController.player = AVPlayer()
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset!))
        
        // Add observer for player status
        player.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        addChild(playerController)
        view.addSubview(playerController.view)
        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerController.view.topAnchor.constraint(equalTo: headerView != nil ? headerView!.bottomAnchor : view.safeAreaLayoutGuide.topAnchor),
            playerController.view.bottomAnchor.constraint(equalTo: trimmer.topAnchor, constant: -16)
        ])
        
        // Add observer for the end of playback
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    @objc private func playerDidFinishPlaying(note: NSNotification) {
        // Directly set the play icon
        // the reason in at this time player.timeControlStatus == .playing still returns true
        playBtn.setImage(self.playIcon, for: .normal)
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
    
    cancelButtonText = config["cancelButtonText"] as? String ?? "Cancel"
    saveButtonText = config["saveButtonText"] as? String ?? "Save"
    jumpToPositionOnLoad = config["jumpToPositionOnLoad"] as? Double ?? 0
    enableHapticFeedback = config["enableHapticFeedback"] as? Bool ?? true
    autoplay = config["autoplay"] as? Bool ?? false
    headerText = config["headerText"] as? String
    headerTextSize = config["headerTextSize"] as? Int ?? 16
    headerTextColor = config["headerTextColor"] as? Double
    
    // Handle new color properties
    if let trimmerColorValue = config["trimmerColor"] as? Double {
        trimmerColor = RCTConvert.uiColor(trimmerColorValue) ?? UIColor.systemYellow
    }
    if let handleIconColorValue = config["handleIconColor"] as? Double {
        handleIconColor = RCTConvert.uiColor(handleIconColorValue) ?? UIColor.black
    }
  }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if player.status == .readyToPlay {
                loadingIndicator.stopAnimating()
                btnStackView.removeArrangedSubview(loadingIndicator)
                loadingIndicator.removeFromSuperview()
                btnStackView.insertArrangedSubview(playBtn, at: 1)
                
                UIView.animate(withDuration: 0.25, animations: {
                    self.playBtn.alpha = 1
                    self.playBtn.isEnabled = true
                    self.saveBtn.alpha = 1
                    self.saveBtn.isEnabled = true
                })
                
                if jumpToPositionOnLoad > 0 {
                    let duration = (asset?.duration.seconds ?? 0) * 1000
                    let time = jumpToPositionOnLoad > duration ? duration : jumpToPositionOnLoad
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
