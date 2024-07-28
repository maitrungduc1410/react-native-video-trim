import UIKit
import AVKit

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
            }
        }
    }
    var maximumDuration: Int?
    var minimumDuration: Int?
    var cancelBtnText = "Cancel"
    var saveButtonText = "Save"
    var cancelBtnClicked: (() -> Void)?
    var saveBtnClicked: ((CMTimeRange) -> Void)?
    var isVideoType = true
    var enableHapticFeedback = true
    
    private let playerController = AVPlayerViewController()
    private var trimmer: VideoTrimmer!
    private var timingStackView: UIStackView!
    private var leadingTrimLabel: UILabel!
    private var currentTimeLabel: UILabel!
    private var trailingTrimLabel: UILabel!
    private var btnStackView: UIStackView!
    private var cancelBtn: UIButton!
    private var playBtn: UIButton!
    private var loadingIndicator = UIActivityIndicatorView()
    private var saveBtn: UIButton!
    private let playIcon = UIImage(systemName: "play.fill")
    private let pauseIcon = UIImage(systemName: "pause.fill")
    private let audioBannerView = UIImage(systemName: "airpodsmax")
    private var player: AVPlayer! { playerController.player }
    private var timeObserverToken: Any?
    
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
        player.seek(to: trimmer.progress, toleranceBefore: .zero, toleranceAfter: .zero)
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
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        // Remove observer
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        
        playerController.player = nil
        playerController.dismiss(animated: false, completion: nil)
    }
    
    @objc private func togglePlay(sender: UIButton) {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            if CMTimeCompare(trimmer.progress, trimmer.selectedRange.end) != -1 {
                trimmer.progress = trimmer.selectedRange.start
                player.seek(to: trimmer.progress, toleranceBefore: .zero, toleranceAfter: .zero)
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
    
    // MARK: - Setup Methods
    private func setupView() {
        view.backgroundColor = .black
    }
    
    private func setupButtons() {
        cancelBtn = UIButton.createButton(title: cancelBtnText, font: .systemFont(ofSize: 18), titleColor: .white, target: self, action: #selector(onCancelBtnClicked))
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
    }
    
    private func setupPlayerController() {
        playerController.showsPlaybackControls = false
        if #available(iOS 16.0, *) {
            playerController.allowsVideoFrameAnalysis = false
        }
        playerController.player = AVPlayer()
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset!))
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        addChild(playerController)
        view.addSubview(playerController.view)
        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
                player.seek(to: trimmer.selectedRange.end, toleranceBefore: .zero, toleranceAfter: .zero)
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
