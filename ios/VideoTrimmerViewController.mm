#import "VideoTrimmerViewController.h"
#import "VideoTrimmer.h"
#import <AVFoundation/AVFoundation.h>


@implementation VideoTrimmerViewController

- (instancetype)init {
    if (self = [super init]) {
        self.cancelButtonText = @"Cancel";
        self.saveButtonText = @"Save";
        self.headerTextSize = 16;
        self.headerTextColor = 0xFFFFFF;
        self.autoplay = NO;
        self.jumpToPositionOnLoad = 0;
        self.enableHapticFeedback = YES;
        self.chaseTime = kCMTimeZero;
        self.isSeekInProgress = NO;
        self.playerController = [[AVPlayerViewController alloc] init];
        self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    }
    return self;
}

- (void)setAsset:(AVAsset *)asset {
    NSLog(@"📱 VideoTrimmerViewController setAsset called with: %@", asset);

    _asset = asset;
    if (asset) {
        [self setupVideoTrimmer];
        [self setupPlayerController];
        [self setupTimeObserver];
        [self updateLabels];
    }
}

- (AVPlayer *)player {
    return self.playerController.player;
}

- (void)onAssetFailToLoad {
    [self.loadingIndicator stopAnimating];
    [self.btnStackView removeArrangedSubview:self.loadingIndicator];
    [self.loadingIndicator removeFromSuperview];
    
    UIView *imageViewContainer = [[UIView alloc] init];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"exclamationmark.triangle.fill"]];
    imageView.tintColor = [UIColor systemYellowColor];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [imageViewContainer addSubview:imageView];
    [NSLayoutConstraint activateConstraints:@[
        [imageView.widthAnchor constraintEqualToConstant:36],
        [imageView.heightAnchor constraintEqualToConstant:36],
        [imageView.centerXAnchor constraintEqualToAnchor:imageViewContainer.centerXAnchor],
        [imageView.centerYAnchor constraintEqualToAnchor:imageViewContainer.centerYAnchor]
    ]];
    imageViewContainer.alpha = 0;
    
    [self.btnStackView insertArrangedSubview:imageViewContainer atIndex:1];
    
    [UIView animateWithDuration:0.25 animations:^{
        imageViewContainer.alpha = 1;
    }];
}

- (void)didBeginTrimmingFromStart:(VideoTrimmer *)sender {
    [self handleBeforeProgressChange];
}

- (void)leadingGrabberChanged:(VideoTrimmer *)sender {
    [self handleProgressChanged:self.trimmer.selectedRange.start];
}

- (void)didEndTrimmingFromStart:(VideoTrimmer *)sender {
    [self handleTrimmingEnd:YES];
}

- (void)didBeginTrimmingFromEnd:(VideoTrimmer *)sender {
    [self handleBeforeProgressChange];
}

- (void)trailingGrabberChanged:(VideoTrimmer *)sender {
    [self handleProgressChanged:CMTimeRangeGetEnd(self.trimmer.selectedRange)];
}

- (void)didEndTrimmingFromEnd:(VideoTrimmer *)sender {
    [self handleTrimmingEnd:NO];
}

- (void)didBeginScrubbing:(VideoTrimmer *)sender {
    [self handleBeforeProgressChange];
}

- (void)didEndScrubbing:(VideoTrimmer *)sender {
    [self updateLabels];
}

- (void)progressDidChanged:(VideoTrimmer *)sender {
    [self handleProgressChanged:self.trimmer.progress];
}

- (void)updateLabels {
    self.leadingTrimLabel.text = [self displayStringFromCMTime:self.trimmer.selectedRange.start];
    self.currentTimeLabel.text = [self displayStringFromCMTime:self.trimmer.progress];
    self.trailingTrimLabel.text = [self displayStringFromCMTime:CMTimeRangeGetEnd(self.trimmer.selectedRange)];
}

- (NSString *)displayStringFromCMTime:(CMTime)time {
    NSTimeInterval offset = CMTimeGetSeconds(time);
    double numberOfNanosecondsFloat = (offset - (NSTimeInterval)((int)offset)) * 100.0;
    int nanoseconds = (int)numberOfNanosecondsFloat;
    
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
    formatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
    
    NSString *timeString = [formatter stringFromTimeInterval:offset] ?: @"00:00";
    return [NSString stringWithFormat:@"%@.%02d", timeString, nanoseconds];
}

- (void)handleBeforeProgressChange {
    [self updateLabels];
    [self.player pause];
    [self setPlayBtnIcon];
}

- (void)handleProgressChanged:(CMTime)time {
    [self updateLabels];
    [self seek:time];
}

- (void)handleTrimmingEnd:(BOOL)start {
    self.trimmer.progress = start ? self.trimmer.selectedRange.start : CMTimeRangeGetEnd(self.trimmer.selectedRange);
    [self updateLabels];
    [self seek:self.trimmer.progress];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupView];
    [self setupButtons];
    [self setupTimeLabels];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (!self.asset) return;
    [self.player pause];
    
    [self.player removeObserver:self forKeyPath:@"status"];
    
    if (self.timeObserverToken) {
        [self.player removeTimeObserver:self.timeObserverToken];
        self.timeObserverToken = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
    
    self.playerController.player = nil;
    [self.playerController dismissViewControllerAnimated:NO completion:nil];
}

- (void)pausePlayer {
    [self.player pause];
    [self setPlayBtnIcon];
}

- (void)togglePlay:(UIButton *)sender {
    if (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
        [self.player pause];
    } else {
        if (CMTimeCompare(self.trimmer.progress, CMTimeRangeGetEnd(self.trimmer.selectedRange)) != -1) {
            self.trimmer.progress = self.trimmer.selectedRange.start;
            [self seek:self.trimmer.progress];
        }
        [self.player play];
    }
    [self setPlayBtnIcon];
}

- (void)onSaveBtnClicked {
    if (self.saveBtnClicked) {
        self.saveBtnClicked(self.trimmer.selectedRange);
    }
}

- (void)onCancelBtnClicked {
    if (self.cancelBtnClicked) {
        self.cancelBtnClicked();
    }
}

- (UIColor *)colorFromHex:(double)hex defaultColor:(UIColor *)defaultColor {
    int32_t hexValue = (int32_t)hex;
    CGFloat red = ((hexValue >> 16) & 0xFF) / 255.0;
    CGFloat green = ((hexValue >> 8) & 0xFF) / 255.0;
    CGFloat blue = (hexValue & 0xFF) / 255.0;
    CGFloat alpha = (hexValue > 0xFFFFFF) ? ((hexValue >> 24) & 0xFF) / 255.0 : 1.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

- (UIButton *)createButtonWithTitle:(NSString *)title 
                               font:(UIFont *)font 
                         titleColor:(UIColor *)titleColor 
                              image:(UIImage *)image 
                          tintColor:(UIColor *)tintColor 
                             target:(id)target 
                             action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    if (title) [button setTitle:title forState:UIControlStateNormal];
    if (image) [button setImage:image forState:UIControlStateNormal];
    if (font) button.titleLabel.font = font;
    if (titleColor) [button setTitleColor:titleColor forState:UIControlStateNormal];
    if (tintColor) button.tintColor = tintColor;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UILabel *)createLabelWithAlignment:(NSTextAlignment)alignment textColor:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    label.textAlignment = alignment;
    label.textColor = color;
    return label;
}

- (void)setupView {
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = [UIColor blackColor];
    
    if (self.headerText) {
        self.headerView = [[UIView alloc] init];
        self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:self.headerView];
        
        UITextView *headerTextView = [[UITextView alloc] init];
        headerTextView.text = self.headerText;
        headerTextView.textAlignment = NSTextAlignmentCenter;
        headerTextView.textColor = [self colorFromHex:self.headerTextColor defaultColor:[UIColor whiteColor]];
        headerTextView.font = [UIFont systemFontOfSize:self.headerTextSize];
        headerTextView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.headerView addSubview:headerTextView];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.headerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [self.headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.headerView.heightAnchor constraintGreaterThanOrEqualToConstant:50],
            
            [headerTextView.topAnchor constraintEqualToAnchor:self.headerView.topAnchor],
            [headerTextView.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
            [headerTextView.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
            [headerTextView.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor],
        ]];
        
        [self.view layoutIfNeeded];
    }
}

- (void)setupButtons {
    self.cancelBtn = [self createButtonWithTitle:self.cancelButtonText 
                                             font:[UIFont systemFontOfSize:18] 
                                       titleColor:[UIColor whiteColor] 
                                            image:nil 
                                        tintColor:nil 
                                           target:self 
                                           action:@selector(onCancelBtnClicked)];
    
    self.playBtn = [self createButtonWithTitle:nil 
                                          font:nil 
                                    titleColor:nil 
                                         image:[UIImage systemImageNamed:@"play.fill"] 
                                     tintColor:[UIColor whiteColor] 
                                        target:self 
                                        action:@selector(togglePlay:)];
    self.playBtn.alpha = 0;
    self.playBtn.enabled = NO;
    
    self.saveBtn = [self createButtonWithTitle:self.saveButtonText 
                                          font:[UIFont systemFontOfSize:18] 
                                    titleColor:[UIColor systemBlueColor] 
                                         image:nil 
                                     tintColor:nil 
                                        target:self 
                                        action:@selector(onSaveBtnClicked)];
    self.saveBtn.alpha = 0;
    self.saveBtn.enabled = NO;
    
    [self.loadingIndicator startAnimating];
    
    self.btnStackView = [[UIStackView alloc] initWithArrangedSubviews:@[self.cancelBtn, self.loadingIndicator, self.saveBtn]];
    self.btnStackView.axis = UILayoutConstraintAxisHorizontal;
    self.btnStackView.alignment = UIStackViewAlignmentCenter;
    self.btnStackView.distribution = UIStackViewDistributionFillEqually;
    self.btnStackView.spacing = UIStackViewSpacingUseSystem;
    self.btnStackView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.btnStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.btnStackView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.btnStackView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.btnStackView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16]
    ]];
}

- (void)setupTimeLabels {
    self.leadingTrimLabel = [self createLabelWithAlignment:NSTextAlignmentLeft textColor:[UIColor whiteColor]];
    self.leadingTrimLabel.text = @"00:00.000";
    
    self.currentTimeLabel = [self createLabelWithAlignment:NSTextAlignmentCenter textColor:[UIColor whiteColor]];
    self.currentTimeLabel.text = @"00:00.000";
    
    self.trailingTrimLabel = [self createLabelWithAlignment:NSTextAlignmentRight textColor:[UIColor whiteColor]];
    self.trailingTrimLabel.text = @"00:00.000";
    
    self.timingStackView = [[UIStackView alloc] initWithArrangedSubviews:@[self.leadingTrimLabel, self.currentTimeLabel, self.trailingTrimLabel]];
    self.timingStackView.axis = UILayoutConstraintAxisHorizontal;
    self.timingStackView.alignment = UIStackViewAlignmentFill;
    self.timingStackView.distribution = UIStackViewDistributionFillEqually;
    self.timingStackView.spacing = UIStackViewSpacingUseSystem;
    self.timingStackView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.timingStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.timingStackView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.timingStackView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.timingStackView.bottomAnchor constraintEqualToAnchor:self.btnStackView.topAnchor constant:-8]
    ]];
}

- (void)setupVideoTrimmer {
    self.trimmer = [[VideoTrimmer alloc] init];
    self.trimmer.asset = self.asset;
    self.trimmer.minimumDuration = CMTimeMake(1 * 600, 600); // 1 second
    self.trimmer.enableHapticFeedback = self.enableHapticFeedback;
    
    if (self.maximumDuration > 0) {
        CMTime maxDuration = CMTimeMake(MAX(1, self.maximumDuration) * 600, 600);
        if (CMTimeCompare(maxDuration, self.asset.duration) > 0) {
            maxDuration = self.asset.duration;
        }
        self.trimmer.maximumDuration = maxDuration;
        self.trimmer.selectedRange = CMTimeRangeMake(kCMTimeZero, maxDuration);
    }
    
    if (self.minimumDuration > 0) {
        self.trimmer.minimumDuration = CMTimeMake(MAX(1, self.minimumDuration) * 600, 600);
    }
    
    // Add target-action for all VideoTrimmer custom events
    [self.trimmer addTarget:self action:@selector(didBeginScrubbing:) forControlEvents:[VideoTrimmer didBeginScrubbing]];
    [self.trimmer addTarget:self action:@selector(didEndScrubbing:) forControlEvents:[VideoTrimmer didEndScrubbing]];
    [self.trimmer addTarget:self action:@selector(progressDidChanged:) forControlEvents:[VideoTrimmer progressChanged]];
    
    [self.trimmer addTarget:self action:@selector(didBeginTrimmingFromStart:) forControlEvents:[VideoTrimmer didBeginTrimmingFromStart]];
    [self.trimmer addTarget:self action:@selector(leadingGrabberChanged:) forControlEvents:[VideoTrimmer leadingGrabberChanged]];
    [self.trimmer addTarget:self action:@selector(didEndTrimmingFromStart:) forControlEvents:[VideoTrimmer didEndTrimmingFromStart]];
    
    [self.trimmer addTarget:self action:@selector(didBeginTrimmingFromEnd:) forControlEvents:[VideoTrimmer didBeginTrimmingFromEnd]];
    [self.trimmer addTarget:self action:@selector(trailingGrabberChanged:) forControlEvents:[VideoTrimmer trailingGrabberChanged]];
    [self.trimmer addTarget:self action:@selector(didEndTrimmingFromEnd:) forControlEvents:[VideoTrimmer didEndTrimmingFromEnd]];
    
    self.trimmer.alpha = 0;
    self.trimmer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.trimmer];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.trimmer.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.trimmer.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.trimmer.bottomAnchor constraintEqualToAnchor:self.timingStackView.topAnchor constant:-16],
        [self.trimmer.heightAnchor constraintEqualToConstant:50]
    ]];
    
    [UIView animateWithDuration:0.25 animations:^{
        self.trimmer.alpha = 1;
    }];
}

- (void)setupPlayerController {
    self.playerController.showsPlaybackControls = NO;
    if (@available(iOS 16.0, *)) {
        self.playerController.allowsVideoFrameAnalysis = NO;
    }
    self.playerController.player = [[AVPlayer alloc] init];
    [self.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithAsset:self.asset]];
    
    [self.player addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
    
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:&error];
    if (error) {
        NSLog(@"AVAudioSession error: %@", error);
    }
    
    [self addChildViewController:self.playerController];
    [self.view addSubview:self.playerController.view];
    self.playerController.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.playerController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.playerController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.playerController.view.topAnchor constraintEqualToAnchor:self.headerView ? self.headerView.bottomAnchor : self.view.safeAreaLayoutGuide.topAnchor],
        [self.playerController.view.bottomAnchor constraintEqualToAnchor:self.trimmer.topAnchor constant:-16]
    ]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
}

- (void)playerDidFinishPlaying:(NSNotification *)notification {
    [self.playBtn setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
}

- (void)setupTimeObserver {
    __weak __typeof__(self) weakSelf = self;
    self.timeObserverToken = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 30) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        if (weakSelf.player.timeControlStatus != AVPlayerTimeControlStatusPlaying) {
            return;
        }
        
        weakSelf.trimmer.progress = time;
        
        if (CMTimeCompare(weakSelf.trimmer.progress, CMTimeRangeGetEnd(weakSelf.trimmer.selectedRange)) == 1) {
            [weakSelf.player pause];
            weakSelf.trimmer.progress = CMTimeRangeGetEnd(weakSelf.trimmer.selectedRange);
            [weakSelf seek:CMTimeRangeGetEnd(weakSelf.trimmer.selectedRange)];
        }
        
        weakSelf.currentTimeLabel.text = [weakSelf displayStringFromCMTime:weakSelf.trimmer.progress];
        [weakSelf setPlayBtnIcon];
    }];
}

- (void)setPlayBtnIcon {
    UIImage *icon = (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) ? 
                    [UIImage systemImageNamed:@"pause.fill"] : 
                    [UIImage systemImageNamed:@"play.fill"];
    [self.playBtn setImage:icon forState:UIControlStateNormal];
}

- (void)seek:(CMTime)time {
    [self seekSmoothlyToTime:time];
}

- (void)seekSmoothlyToTime:(CMTime)newChaseTime {
    if (CMTimeCompare(newChaseTime, self.chaseTime) != 0) {
        self.chaseTime = newChaseTime;
        
        if (!self.isSeekInProgress) {
            [self trySeekToChaseTime];
        }
    }
}

- (void)trySeekToChaseTime {
    if (self.player.status != AVPlayerStatusReadyToPlay) return;
    [self actuallySeekToTime];
}

- (void)actuallySeekToTime {
    self.isSeekInProgress = YES;
    CMTime seekTimeInProgress = self.chaseTime;
    
    [self.player seekToTime:seekTimeInProgress toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        if (CMTimeCompare(seekTimeInProgress, self.chaseTime) == 0) {
            self.isSeekInProgress = NO;
        } else {
            [self trySeekToChaseTime];
        }
    }];
}

- (void)configureWithConfig:(JS::NativeVideoTrim::EditorConfig)config {
    if (config.maxDuration() > 0) {
        self.maximumDuration = (NSInteger)config.maxDuration();
    }
    
    if (config.minDuration() > 0) {
        self.minimumDuration = (NSInteger)config.minDuration();
    }
    
    self.cancelButtonText = config.cancelButtonText();
    self.saveButtonText = config.saveButtonText();
    self.jumpToPositionOnLoad = config.jumpToPositionOnLoad();
    
    self.enableHapticFeedback = config.enableHapticFeedback();
    self.autoplay = config.autoplay();
    
    NSString *headerText = config.headerText();
    if (headerText && headerText.length > 0) {
        self.headerText = headerText;
        self.headerTextSize = (NSInteger)config.headerTextSize();
        self.headerTextColor = config.headerTextColor();
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        if (self.player.status == AVPlayerStatusReadyToPlay) {
            [self.loadingIndicator stopAnimating];
            [self.btnStackView removeArrangedSubview:self.loadingIndicator];
            [self.loadingIndicator removeFromSuperview];
            [self.btnStackView insertArrangedSubview:self.playBtn atIndex:1];
            
            [UIView animateWithDuration:0.25 animations:^{
                self.playBtn.alpha = 1;
                self.playBtn.enabled = YES;
                self.saveBtn.alpha = 1;
                self.saveBtn.enabled = YES;
            }];
            
            if (self.jumpToPositionOnLoad > 0) {
                double duration = CMTimeGetSeconds(self.asset.duration) * 1000;
                double time = (self.jumpToPositionOnLoad > duration) ? duration : self.jumpToPositionOnLoad;
                CMTime cmtime = CMTimeMake((CMTimeValue)time, 1000);
                
                [self seek:cmtime];
                self.trimmer.progress = cmtime;
                self.currentTimeLabel.text = [self displayStringFromCMTime:self.trimmer.progress];
            }
            
            if (self.autoplay) {
                [self togglePlay:self.playBtn];
            }
        }
    }
}

@end
