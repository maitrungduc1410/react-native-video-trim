//
//  VideoTrimmerViewController.swift
//  react-native-video-trim
//
//  Created by Duc Trung Mai on 17/1/24.
//

import UIKit
import AVKit

extension CMTime {
    var displayString: String {
        let offset = TimeInterval(seconds)
        let numberOfNanosecondsFloat = (offset - TimeInterval(Int(offset))) * 1000.0
        let nanoseconds = Int(numberOfNanosecondsFloat)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return String(format: "%@.%03d", formatter.string(from: offset) ?? "00:00", nanoseconds)
    }
}

extension AVAsset {
    var fullRange: CMTimeRange {
        return CMTimeRange(start: .zero, duration: duration)
    }
    func trimmedComposition(_ range: CMTimeRange) -> AVAsset {
        guard CMTimeRangeEqual(fullRange, range) == false else {return self}
        
        let composition = AVMutableComposition()
        try? composition.insertTimeRange(range, of: self, at: .zero)
        
        if let videoTrack = tracks(withMediaType: .video).first {
            composition.tracks.forEach {$0.preferredTransform = videoTrack.preferredTransform}
        }
        return composition
    }
}

@available(iOS 13.0, *)
class VideoTrimmerViewController: UIViewController {
    var asset: AVAsset!
    var maximumDuration: Int?
    var cancelBtnText = "Cancel"
    var saveButtonText = "Save"
    var cancelBtnClicked: (() -> Void)?
    var saveBtnClicked: ((CMTimeRange) -> Void)?
    
    let playerController = AVPlayerViewController()
    var trimmer: VideoTrimmer!
    var timingStackView: UIStackView!
    var leadingTrimLabel: UILabel!
    var currentTimeLabel: UILabel!
    var trailingTrimLabel: UILabel!
    
    private var btnStackView: UIStackView!
    private var cancelBtn: UIButton!
    private var playBtn: UIButton!
    private var saveBtn: UIButton!
    private let playIcon = UIImage(systemName: "play.fill")
    private let pauseIcon = UIImage(systemName: "pause.fill")
    
    private var wasPlaying = false
    private var player: AVPlayer! {playerController.player}
    private var timeObserverToken: Any?
    
    
    // MARK: - Input
    @objc private func didBeginTrimming(_ sender: VideoTrimmer) {
        updateLabels()
        
        wasPlaying = (player.timeControlStatus != .paused)
        player.pause()
        
        updatePlayerAsset()
    }
    
    @objc private func didEndTrimming(_ sender: VideoTrimmer) {
        updateLabels()
        
        if wasPlaying == true {
            player.play()
        }
        
        updatePlayerAsset()
    }
    
    @objc private func selectedRangeDidChanged(_ sender: VideoTrimmer) {
        updateLabels()
    }
    
    @objc private func didBeginScrubbing(_ sender: VideoTrimmer) {
        updateLabels()
        
        wasPlaying = (player.timeControlStatus != .paused)
        player.pause()
    }
    
    @objc private func didEndScrubbing(_ sender: VideoTrimmer) {
        updateLabels()
        
        if wasPlaying == true {
            player.play()
        }
    }
    
    @objc private func progressDidChanged(_ sender: VideoTrimmer) {
        updateLabels()
        
        let time = CMTimeSubtract(trimmer.progress, trimmer.selectedRange.start)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    // MARK: - Private
    private func updateLabels() {
        leadingTrimLabel.text = trimmer.selectedRange.start.displayString
        currentTimeLabel.text = trimmer.progress.displayString
        trailingTrimLabel.text = trimmer.selectedRange.end.displayString
    }
    
    private func updatePlayerAsset() {
        let outputRange = trimmer.trimmingState == .none ? trimmer.selectedRange : asset.fullRange
        let trimmedAsset = asset.trimmedComposition(outputRange)
        if trimmedAsset != player.currentItem?.asset {
            player.replaceCurrentItem(with: AVPlayerItem(asset: trimmedAsset))
        }
    }
    
    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        // bottom action buttons
        cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(cancelBtnText, for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 18)
        cancelBtn.setTitleColor(.white, for: .normal)
        cancelBtn.addTarget(self, action: #selector(onCancelBtnClicked), for: .touchUpInside)
        
        
        playBtn = UIButton(type: .system)
        playBtn.setImage(playIcon, for: .normal)
        playBtn.tintColor = .systemBlue
        playBtn.addTarget(self, action: #selector(togglePlay(sender:)), for: .touchUpInside)
        
        saveBtn = UIButton(type: .system)
        saveBtn.setTitle(saveButtonText, for: .normal)
        saveBtn.titleLabel?.font = .systemFont(ofSize: 18)
        saveBtn.setTitleColor(.systemBlue, for: .normal)
        saveBtn.addTarget(self, action: #selector(onSaveBtnClicked), for: .touchUpInside)
        
        btnStackView = UIStackView(arrangedSubviews: [cancelBtn, playBtn, saveBtn])
        btnStackView.axis = .horizontal
        btnStackView.alignment = .fill
        btnStackView.distribution = .fillEqually
        btnStackView.spacing = UIStackView.spacingUseSystem
        view.addSubview(btnStackView)
        btnStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btnStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            btnStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            btnStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
        
        // time labels
        leadingTrimLabel = UILabel()
        leadingTrimLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        leadingTrimLabel.textAlignment = .left
        leadingTrimLabel.textColor = .white
        
        currentTimeLabel = UILabel()
        currentTimeLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        currentTimeLabel.textAlignment = .center
        currentTimeLabel.textColor = .white
        
        trailingTrimLabel = UILabel()
        trailingTrimLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        trailingTrimLabel.textAlignment = .right
        trailingTrimLabel.textColor = .white
        
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
            timingStackView.bottomAnchor.constraint(equalTo: btnStackView.topAnchor, constant: -8),
        ])
        
        // THIS IS WHERE WE SETUP THE VIDEOTRIMMER:
        trimmer = VideoTrimmer()
        trimmer.asset = asset // this should happen before trimmer.selectedRange below otherwise its didSet will override
        trimmer.minimumDuration = CMTime(seconds: 1, preferredTimescale: 600)
        
        if maximumDuration != nil {
            trimmer.maximumDuration = CMTime(seconds: max(1, Double(maximumDuration!)), preferredTimescale: 600) // minimum 1 second
            
            // guard check to make sure max duration can only <= asset.duration
            if CMTimeCompare(trimmer.maximumDuration, asset.duration) == 1 {
                trimmer.maximumDuration = asset.duration
            }
            
            trimmer.selectedRange = CMTimeRange(start: .zero, end: trimmer.maximumDuration)
        }
        
        trimmer.addTarget(self, action: #selector(didBeginTrimming(_:)), for: VideoTrimmer.didBeginTrimming)
        trimmer.addTarget(self, action: #selector(didEndTrimming(_:)), for: VideoTrimmer.didEndTrimming)
        trimmer.addTarget(self, action: #selector(selectedRangeDidChanged(_:)), for: VideoTrimmer.selectedRangeChanged)
        trimmer.addTarget(self, action: #selector(didBeginScrubbing(_:)), for: VideoTrimmer.didBeginScrubbing)
        trimmer.addTarget(self, action: #selector(didEndScrubbing(_:)), for: VideoTrimmer.didEndScrubbing)
        trimmer.addTarget(self, action: #selector(progressDidChanged(_:)), for: VideoTrimmer.progressChanged)
        view.addSubview(trimmer)
        trimmer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            trimmer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            trimmer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            trimmer.bottomAnchor.constraint(equalTo: timingStackView.topAnchor, constant: -16),
            trimmer.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        playerController.showsPlaybackControls = false // hide control buttons
        if #available(iOS 16.0, *) {
            playerController.allowsVideoFrameAnalysis = false // hide live text
        }
        playerController.player = AVPlayer()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: []) // this is to play audio even when device is in silent mode
        addChild(playerController)
        view.addSubview(playerController.view)
        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            playerController.view.bottomAnchor.constraint(equalTo: trimmer.topAnchor, constant: -16)
        ])
        
        updatePlayerAsset()
        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            guard let self = self else {return}
            // when we're not trimming, the players starting point is actual later than the trimmer,
            // (because the vidoe has been trimmed), so we need to account for that.
            // When we're trimming, we always show the full video
            let finalTime = self.trimmer.trimmingState == .none ? CMTimeAdd(time, self.trimmer.selectedRange.start) : time
            self.trimmer.progress = finalTime
            
            if player.timeControlStatus == .playing {
                playBtn.setImage(pauseIcon, for: .normal)
            } else {
                playBtn.setImage(playIcon, for: .normal)
            }
        }
        
        updateLabels()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        player.pause()
        if timeObserverToken != nil {
            player.removeTimeObserver(timeObserverToken as Any)
            timeObserverToken = nil
        }
        playerController.player  = nil
        playerController.dismiss(animated: false, completion: nil)
    }
    
    @objc private func togglePlay(sender: UIButton) {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
        
    }
    
    @objc func onSaveBtnClicked() {
        saveBtnClicked?(trimmer.selectedRange)
    }
    
    @objc func onCancelBtnClicked() {
        cancelBtnClicked?()
    }
}
