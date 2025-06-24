#import "VideoTrimmer.h"
#import "VideoTrimmerThumb.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface VideoTrimmer ()

// UI Components
@property (nonatomic, strong) VideoTrimmerThumb *thumbView;
@property (nonatomic, strong) UIView *wrapperView;
@property (nonatomic, strong) UIView *shadowView;
@property (nonatomic, strong) UIView *thumbnailClipView;
@property (nonatomic, strong) UIView *thumbnailWrapperView;
@property (nonatomic, strong) UIView *thumbnailTrackView;
@property (nonatomic, strong) UIView *thumbnailLeadingCoverView;
@property (nonatomic, strong) UIView *thumbnailTrailingCoverView;
@property (nonatomic, strong) UIView *leadingThumbRest;
@property (nonatomic, strong) UIView *trailingThumbRest;
@property (nonatomic, strong) UIView *progressIndicator;
@property (nonatomic, strong) UIControl *progressIndicatorControl;

// Timing and state properties
@property (nonatomic, assign, readwrite) CMTimeRange range;
@property (nonatomic, assign, readwrite) BOOL isZoomedIn;
@property (nonatomic, assign, readwrite) CMTimeRange zoomedInRange;
@property (nonatomic, assign, readwrite) BOOL isScrubbing;
@property (nonatomic, assign) CGFloat grabberOffset;

// Thumbnail management
@property (nonatomic, assign) CGSize lastKnownViewSizeForThumbnailGeneration;
@property (nonatomic, assign) CGSize thumbnailSize;
@property (nonatomic, assign) CMTimeRange lastKnownThumbnailRange;
@property (nonatomic, strong) NSMutableArray *thumbnails;
@property (nonatomic, strong) AVAssetImageGenerator *generator;

// Haptic feedback
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactFeedbackGenerator;
@property (nonatomic, assign) BOOL didClampWhilePanning;

// Timers
@property (nonatomic, strong) NSTimer *zoomWaitTimer;

// Gesture recognizers
@property (nonatomic, strong, readwrite) UILongPressGestureRecognizer *leadingGestureRecognizer;
@property (nonatomic, strong, readwrite) UILongPressGestureRecognizer *trailingGestureRecognizer;
@property (nonatomic, strong, readwrite) UILongPressGestureRecognizer *progressGestureRecognizer;
@property (nonatomic, strong, readwrite) UILongPressGestureRecognizer *thumbnailInteractionGestureRecognizer;

@end

@interface VideoTrimmerThumbnail : NSObject
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, assign) CMTime time;
- (instancetype)initWithImageView:(UIImageView *)imageView time:(CMTime)time;
@end

@implementation VideoTrimmerThumbnail
- (instancetype)initWithImageView:(UIImageView *)imageView time:(CMTime)time {
    if (self = [super init]) {
        self.uuid = [[NSUUID UUID] UUIDString];
        self.imageView = imageView;
        self.time = time;
    }
    return self;
}
@end

// Helper functions
CGFloat SnapToDevicePixels(CGFloat value) {
    CGFloat scale = [UIScreen mainScreen].scale;
    return round(value * scale) / scale;
}

CGRect SnapToDevicePixelsRect(CGRect rect) {
    return CGRectMake(
        SnapToDevicePixels(rect.origin.x),
        SnapToDevicePixels(rect.origin.y),
        SnapToDevicePixels(CGRectGetMaxX(rect) - rect.origin.x),
        SnapToDevicePixels(CGRectGetMaxY(rect) - rect.origin.y)
    );
}

CGSize ApplyVideoTransform(CGSize size, CGAffineTransform transform) {
    return CGRectApplyAffineTransform(CGRectMake(0, 0, size.width, size.height), transform).size;
}

@implementation VideoTrimmer

+ (UIControlEvents)didBeginTrimmingFromStart { return (UIControlEvents)(1 << 19); }
+ (UIControlEvents)leadingGrabberChanged { return (UIControlEvents)(1 << 20); }
+ (UIControlEvents)didEndTrimmingFromStart { return (UIControlEvents)(1 << 21); }
+ (UIControlEvents)didBeginTrimmingFromEnd { return (UIControlEvents)(1 << 22); }
+ (UIControlEvents)trailingGrabberChanged { return (UIControlEvents)(1 << 23); }
+ (UIControlEvents)didEndTrimmingFromEnd { return (UIControlEvents)(1 << 24); }
+ (UIControlEvents)didBeginScrubbing { return (UIControlEvents)(0b00001000 << 24); }
+ (UIControlEvents)progressChanged { return (UIControlEvents)(0b00010000 << 24); }
+ (UIControlEvents)didEndScrubbing { return (UIControlEvents)(0b00100000 << 24); }

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self setup];
    }
    return self;
}

- (void)setAsset:(AVAsset *)asset {
    _asset = asset;
    if (asset) {
        CMTime duration = asset.duration;
        self.range = CMTimeRangeMake(kCMTimeZero, duration);
        self.selectedRange = self.range;
        self.lastKnownViewSizeForThumbnailGeneration = CGSizeZero;
        [self setNeedsLayout];
    }
}

- (void)setVideoComposition:(AVVideoComposition *)videoComposition {
    _videoComposition = videoComposition;
    self.lastKnownViewSizeForThumbnailGeneration = CGSizeZero;
    [self setNeedsLayout];
}

- (void)setRange:(CMTimeRange)range {
    _range = range;
    [self setNeedsLayout];
}

- (void)setSelectedRange:(CMTimeRange)selectedRange {
    _selectedRange = selectedRange;
    [self setNeedsLayout];
}

- (void)setProgress:(CMTime)progress {
    _progress = progress;
    [self setNeedsLayout];
}

- (void)setProgressIndicatorMode:(VideoTrimmerProgressIndicatorMode)progressIndicatorMode {
    _progressIndicatorMode = progressIndicatorMode;
    [self updateProgressIndicator];
}

- (void)setTrimmingState:(VideoTrimmerTrimmingState)trimmingState {
    _trimmingState = trimmingState;
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.shadowView.layer.shadowOpacity = (trimmingState != VideoTrimmerTrimmingStateNone) ? 0.5 : 0.25;
        self.shadowView.layer.shadowRadius = (trimmingState != VideoTrimmerTrimmingStateNone) ? 4 : 2;
    } completion:nil];
}

- (void)setTrackBackgroundColor:(UIColor *)trackBackgroundColor {
    _trackBackgroundColor = trackBackgroundColor;
    self.thumbnailWrapperView.backgroundColor = trackBackgroundColor;
}

- (void)setThumbRestColor:(UIColor *)thumbRestColor {
    _thumbRestColor = thumbRestColor;
    self.leadingThumbRest.backgroundColor = thumbRestColor;
    self.trailingThumbRest.backgroundColor = thumbRestColor;
}

- (CMTimeRange)visibleRange {
    return self.isZoomedIn ? self.zoomedInRange : self.range;
}

- (CMTime)selectedTime {
    switch (self.trimmingState) {
        case VideoTrimmerTrimmingStateNone:
            return kCMTimeZero;
        case VideoTrimmerTrimmingStateLeading:
            return self.selectedRange.start;
        case VideoTrimmerTrimmingStateTrailing:
            return CMTimeRangeGetEnd(self.selectedRange);
    }
}

- (void)setup {
    // Initialize properties
    self.horizontalInset = 16;
    self.minimumDuration = CMTimeMake(600, 600); // 1 second
    self.maximumDuration = kCMTimePositiveInfinity;
    self.enableHapticFeedback = YES;
    self.range = kCMTimeRangeInvalid;
    self.selectedRange = kCMTimeRangeInvalid;
    self.progressIndicatorMode = VideoTrimmerProgressIndicatorModeHiddenOnlyWhenTrimming;
    self.progress = kCMTimeZero;
    self.trimmingState = VideoTrimmerTrimmingStateNone;
    self.isZoomedIn = NO;
    self.zoomedInRange = kCMTimeRangeZero;
    self.isScrubbing = NO;
    self.trackBackgroundColor = [UIColor blackColor];
    self.thumbRestColor = [UIColor blackColor];
    self.lastKnownViewSizeForThumbnailGeneration = CGSizeZero;
    self.thumbnailSize = CGSizeZero;
    self.lastKnownThumbnailRange = kCMTimeRangeZero;
    self.thumbnails = [[NSMutableArray alloc] init];
    
    // Initialize UI components
    self.thumbView = [[VideoTrimmerThumb alloc] init];
    self.thumbView.accessibilityIdentifier = @"thumbView";
    
    self.wrapperView = [[UIView alloc] init];
    self.wrapperView.accessibilityIdentifier = @"wrapperView";
    self.wrapperView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.shadowView = [[UIView alloc] init];
    self.shadowView.accessibilityIdentifier = @"shadowView";
    self.shadowView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.thumbnailClipView = [[UIView alloc] init];
    self.thumbnailClipView.accessibilityIdentifier = @"thumbnailClipView";
    self.thumbnailClipView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.thumbnailWrapperView = [[UIView alloc] init];
    self.thumbnailWrapperView.accessibilityIdentifier = @"thumbnailWrapperView";
    
    self.thumbnailTrackView = [[UIView alloc] init];
    self.thumbnailTrackView.accessibilityIdentifier = @"thumbnailTrackView";
    
    self.thumbnailLeadingCoverView = [[UIView alloc] init];
    self.thumbnailLeadingCoverView.accessibilityIdentifier = @"thumbnailLeadingCoverView";
    
    self.thumbnailTrailingCoverView = [[UIView alloc] init];
    self.thumbnailTrailingCoverView.accessibilityIdentifier = @"thumbnailTrailingCoverView";
    
    self.leadingThumbRest = [[UIView alloc] init];
    self.leadingThumbRest.accessibilityIdentifier = @"leadingThumbRest";
    self.leadingThumbRest.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.trailingThumbRest = [[UIView alloc] init];
    self.trailingThumbRest.accessibilityIdentifier = @"trailingThumbRest";
    self.trailingThumbRest.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.progressIndicator = [[UIView alloc] init];
    self.progressIndicator.accessibilityIdentifier = @"progressIndicator";
    
    self.progressIndicatorControl = [[UIControl alloc] init];
    self.progressIndicatorControl.accessibilityIdentifier = @"progressIndicatorControl";
    
    // Set up view hierarchy
    [self addSubview:self.thumbnailClipView];
    [self.thumbnailClipView addSubview:self.thumbnailWrapperView];
    [self.thumbnailWrapperView addSubview:self.leadingThumbRest];
    [self.thumbnailWrapperView addSubview:self.trailingThumbRest];
    [self.thumbnailWrapperView addSubview:self.thumbnailTrackView];
    [self.thumbnailWrapperView addSubview:self.thumbnailLeadingCoverView];
    [self.thumbnailWrapperView addSubview:self.thumbnailTrailingCoverView];
    
    [self addSubview:self.shadowView];
    self.wrapperView.clipsToBounds = YES;
    [self.shadowView addSubview:self.wrapperView];
    [self.wrapperView addSubview:self.thumbView];
    [self.wrapperView addSubview:self.progressIndicator];
    [self.wrapperView addSubview:self.progressIndicatorControl];
    
    // Configure styles
    self.progressIndicator.backgroundColor = [UIColor whiteColor];
    self.progressIndicator.layer.shadowColor = [UIColor blackColor].CGColor;
    self.progressIndicator.layer.shadowOffset = CGSizeZero;
    self.progressIndicator.layer.shadowRadius = 2;
    self.progressIndicator.layer.shadowOpacity = 0.25;
    self.progressIndicator.layer.cornerRadius = 2;
    if (@available(iOS 13.0, *)) {
        self.progressIndicator.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    self.thumbnailClipView.clipsToBounds = YES;
    self.thumbnailTrackView.clipsToBounds = YES;
    self.thumbnailLeadingCoverView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    self.thumbnailTrailingCoverView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    
    self.leadingThumbRest.backgroundColor = self.thumbRestColor;
    self.trailingThumbRest.backgroundColor = self.thumbRestColor;
    
    self.thumbnailWrapperView.backgroundColor = self.trackBackgroundColor;
    self.thumbnailWrapperView.layer.cornerRadius = 6;
    if (@available(iOS 13.0, *)) {
        self.thumbnailWrapperView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    self.leadingThumbRest.layer.cornerRadius = 6;
    self.leadingThumbRest.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner;
    if (@available(iOS 13.0, *)) {
        self.leadingThumbRest.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    self.trailingThumbRest.layer.cornerRadius = 6;
    self.trailingThumbRest.layer.maskedCorners = kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner;
    if (@available(iOS 13.0, *)) {
        self.trailingThumbRest.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    self.shadowView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.shadowView.layer.shadowOffset = CGSizeZero;
    self.shadowView.layer.shadowRadius = 2;
    self.shadowView.layer.shadowOpacity = 0.25;
    
    [self setupConstraints];
    [self setupGestures];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        [self.thumbnailClipView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.thumbnailClipView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.thumbnailClipView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.thumbnailClipView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        
        [self.shadowView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.shadowView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.shadowView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.shadowView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        
        [self.wrapperView.topAnchor constraintEqualToAnchor:self.shadowView.topAnchor],
        [self.wrapperView.bottomAnchor constraintEqualToAnchor:self.shadowView.bottomAnchor],
        [self.wrapperView.leadingAnchor constraintEqualToAnchor:self.shadowView.leadingAnchor],
        [self.wrapperView.trailingAnchor constraintEqualToAnchor:self.shadowView.trailingAnchor],
        
        [self.leadingThumbRest.topAnchor constraintEqualToAnchor:self.thumbnailWrapperView.topAnchor],
        [self.leadingThumbRest.bottomAnchor constraintEqualToAnchor:self.thumbnailWrapperView.bottomAnchor],
        [self.leadingThumbRest.leadingAnchor constraintEqualToAnchor:self.thumbnailWrapperView.leadingAnchor],
        [self.leadingThumbRest.widthAnchor constraintEqualToConstant:self.thumbView.chevronWidth],
        
        [self.trailingThumbRest.topAnchor constraintEqualToAnchor:self.thumbnailWrapperView.topAnchor],
        [self.trailingThumbRest.bottomAnchor constraintEqualToAnchor:self.thumbnailWrapperView.bottomAnchor],
        [self.trailingThumbRest.trailingAnchor constraintEqualToAnchor:self.thumbnailWrapperView.trailingAnchor],
        [self.trailingThumbRest.widthAnchor constraintEqualToConstant:self.thumbView.chevronWidth]
    ]];
}

- (void)setupGestures {
    self.leadingGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(leadingGrabberPanned:)];
    self.leadingGestureRecognizer.allowableMovement = CGFLOAT_MAX;
    self.leadingGestureRecognizer.minimumPressDuration = 0;
    [self.thumbView.leadingGrabber addGestureRecognizer:self.leadingGestureRecognizer];
    
    self.trailingGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(trailingGrabberPanned:)];
    self.trailingGestureRecognizer.allowableMovement = CGFLOAT_MAX;
    self.trailingGestureRecognizer.minimumPressDuration = 0;
    [self.thumbView.trailingGrabber addGestureRecognizer:self.trailingGestureRecognizer];
    
    self.progressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(progressGrabberPanned:)];
    self.progressGestureRecognizer.allowableMovement = CGFLOAT_MAX;
    self.progressGestureRecognizer.minimumPressDuration = 0;
    [self.progressGestureRecognizer requireGestureRecognizerToFail:self.leadingGestureRecognizer];
    [self.progressGestureRecognizer requireGestureRecognizerToFail:self.trailingGestureRecognizer];
    [self.progressIndicatorControl addGestureRecognizer:self.progressGestureRecognizer];
    
    self.thumbnailInteractionGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(thumbnailPanned:)];
    self.thumbnailInteractionGestureRecognizer.allowableMovement = CGFLOAT_MAX;
    self.thumbnailInteractionGestureRecognizer.minimumPressDuration = 0;
    [self.thumbnailInteractionGestureRecognizer requireGestureRecognizerToFail:self.leadingGestureRecognizer];
    [self.thumbnailInteractionGestureRecognizer requireGestureRecognizerToFail:self.trailingGestureRecognizer];
    [self.thumbView addGestureRecognizer:self.thumbnailInteractionGestureRecognizer];
}

- (void)regenerateThumbnailsIfNeeded {
    CGSize size = self.bounds.size;
    if (size.width <= 0 || size.height <= 0) return;
    if (CGSizeEqualToSize(self.lastKnownViewSizeForThumbnailGeneration, size) && CMTimeRangeEqual(self.lastKnownThumbnailRange, [self visibleRange])) return;
    if (!self.asset) return;
    
    NSArray<AVAssetTrack *> *videoTracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    if (videoTracks.count == 0) return;
    AVAssetTrack *track = videoTracks.firstObject;
    
    self.lastKnownViewSizeForThumbnailGeneration = size;
    self.lastKnownThumbnailRange = [self visibleRange];
    
    CGSize naturalSize = track.naturalSize;
    CGAffineTransform transform = track.preferredTransform;
    CGSize fixedSize = ApplyVideoTransform(naturalSize, transform);
    
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:self.asset];
    generator.apertureMode = AVAssetImageGeneratorApertureModeCleanAperture;
    generator.videoComposition = self.videoComposition;
    self.generator = generator;
    
    CGFloat height = size.height - self.thumbView.edgeHeight * 2;
    self.thumbnailSize = CGSizeMake(height / fixedSize.height * fixedSize.width, height);
    NSInteger numberOfThumbnails = (NSInteger)ceil(size.width / self.thumbnailSize.width);
    
    NSMutableArray *newThumbnails = [[NSMutableArray alloc] init];
    double thumbnailDuration = CMTimeGetSeconds([self visibleRange].duration) / (double)numberOfThumbnails;
    NSMutableArray *times = [[NSMutableArray alloc] init];
    
    for (NSInteger index = -3; index < numberOfThumbnails + 6; index++) {
        CMTime time = CMTimeAdd([self visibleRange].start, CMTimeMakeWithSeconds(thumbnailDuration * (double)index, self.asset.duration.timescale * 2));
        if (CMTimeCompare(time, kCMTimeZero) < 0) continue;
        [times addObject:[NSValue valueWithCMTime:time]];
        
        UIImageView *imageView = [[UIImageView alloc] init];
        VideoTrimmerThumbnail *newThumbnail = [[VideoTrimmerThumbnail alloc] initWithImageView:imageView time:time];
        [self.thumbnailTrackView addSubview:imageView];
        [newThumbnails addObject:newThumbnail];
    }
    
    generator.appliesPreferredTrackTransform = YES;
    CGFloat scale = [UIScreen mainScreen].scale;
    generator.maximumSize = CGSizeMake(self.thumbnailSize.width * scale, self.thumbnailSize.height * scale);
    
    NSArray *oldThumbnails = [self.thumbnails copy];
    [self.thumbnails addObjectsFromArray:newThumbnails];
    
    [UIView animateWithDuration:0.25 delay:0.25 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        for (VideoTrimmerThumbnail *thumbnail in oldThumbnails) {
            thumbnail.imageView.alpha = 0;
        }
    } completion:^(BOOL finished) {
        for (VideoTrimmerThumbnail *thumbnail in oldThumbnails) {
            [thumbnail.imageView removeFromSuperview];
        }
        NSSet *uuidsToRemove = [NSSet setWithArray:[oldThumbnails valueForKey:@"uuid"]];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (uuid IN %@)", uuidsToRemove];
        self.thumbnails = [[self.thumbnails filteredArrayUsingPredicate:predicate] mutableCopy];
    }];
    
    __block NSInteger seenIndex = 0;
    generator.requestedTimeToleranceBefore = kCMTimeZero;
    generator.requestedTimeToleranceAfter = kCMTimeZero;
    
    [generator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef cgImage, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * error) {
        seenIndex++;
        
        if (!cgImage) return;
        UIImage *image = [UIImage imageWithCGImage:cgImage];
        
        if (seenIndex <= newThumbnails.count) {
            UIImageView *imageView = ((VideoTrimmerThumbnail *)newThumbnails[seenIndex - 1]).imageView;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView transitionWithView:imageView duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                    imageView.image = image;
                } completion:nil];
            });
        }
    }];
}

- (CMTime)timeForLocation:(CGFloat)x {
    CGSize size = self.bounds.size;
    CGFloat inset = self.thumbView.chevronWidth + self.horizontalInset;
    CGFloat offset = x - inset;
    
    CGFloat availableWidth = size.width - inset * 2;
    CGFloat visibleDurationInSeconds = (CGFloat)CMTimeGetSeconds([self visibleRange].duration);
    CGFloat ratio = visibleDurationInSeconds != 0 ? availableWidth / visibleDurationInSeconds : 0;
    
    CMTime timeDifference = CMTimeMakeWithSeconds((double)(offset / ratio), 600);
    return CMTimeAdd([self visibleRange].start, timeDifference);
}

- (CGFloat)locationForTime:(CMTime)time {
    CGSize size = self.bounds.size;
    CGFloat inset = self.thumbView.chevronWidth + self.horizontalInset;
    CGFloat availableWidth = size.width - inset * 2;
    
    CMTime offset = CMTimeSubtract(time, [self visibleRange].start);
    
    CGFloat visibleDurationInSeconds = (CGFloat)CMTimeGetSeconds([self visibleRange].duration);
    CGFloat ratio = visibleDurationInSeconds != 0 ? availableWidth / visibleDurationInSeconds : 0;
    
    CGFloat location = (CGFloat)CMTimeGetSeconds(offset) * ratio;
    return SnapToDevicePixels(location) + inset;
}

- (void)startZoomWaitTimer {
    [self stopZoomWaitTimer];
    if (self.isZoomedIn) return;
    
    self.zoomWaitTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [self stopZoomWaitTimer];
        [self zoomIfNeeded];
    }];
}

- (void)stopZoomWaitTimer {
    [self.zoomWaitTimer invalidate];
    self.zoomWaitTimer = nil;
}

- (void)stopZoomIfNeeded {
    [self stopZoomWaitTimer];
    self.isZoomedIn = NO;
    [self animateChanges];
}

- (void)zoomIfNeeded {
    if (self.isZoomedIn) return;
    
    CGSize size = self.bounds.size;
    CGFloat inset = self.thumbView.chevronWidth + self.horizontalInset;
    CGFloat availableWidth = size.width - inset * 2;
    CGFloat newDuration = (CGFloat)(CMTimeGetSeconds(self.range.duration) > 4 ? 2.0 : CMTimeGetSeconds(self.range.duration) * 0.5);
    
    CMTime durationTime = CMTimeMakeWithSeconds((double)newDuration, 600);
    
    if (self.trimmingState == VideoTrimmerTrimmingStateLeading) {
        CGFloat position = [self locationForTime:self.selectedRange.start] - inset;
        CGFloat start = position / availableWidth * newDuration;
        self.zoomedInRange = CMTimeRangeMake(CMTimeSubtract(self.selectedRange.start, CMTimeMakeWithSeconds((double)start, 600)), durationTime);
    } else {
        CGFloat position = [self locationForTime:CMTimeRangeGetEnd(self.selectedRange)] - inset;
        CGFloat durationToStart = position / availableWidth * newDuration;
        CMTime newStart = CMTimeSubtract(CMTimeRangeGetEnd(self.selectedRange), CMTimeMakeWithSeconds((double)durationToStart, 600));
        self.zoomedInRange = CMTimeRangeMake(newStart, durationTime);
    }
    
    self.isZoomedIn = YES;
    [self animateChanges];
    
    if (self.enableHapticFeedback) {
        UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
        [generator selectionChanged];
    }
}

- (void)animateChanges {
    [self setNeedsLayout];
    [self.thumbView setNeedsLayout];
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
        [self layoutIfNeeded];
        [self.thumbView layoutIfNeeded];
    } completion:nil];
}

- (void)startPanning {
    self.didClampWhilePanning = NO;
    
    if (self.enableHapticFeedback) {
        UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
        [generator selectionChanged];
        self.impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [self.impactFeedbackGenerator prepare];
    }
    
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
        [self updateProgressIndicator];
    } completion:nil];
}

- (void)stopPanning {
    self.trimmingState = VideoTrimmerTrimmingStateNone;
    [self stopZoomIfNeeded];
    self.impactFeedbackGenerator = nil;
    
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
        [self updateProgressIndicator];
    } completion:nil];
}

- (void)updateProgressIndicator {
    switch (self.progressIndicatorMode) {
        case VideoTrimmerProgressIndicatorModeAlwaysHidden:
            self.progressIndicator.alpha = 0;
            self.progressIndicatorControl.userInteractionEnabled = NO;
            break;
            
        case VideoTrimmerProgressIndicatorModeAlwaysShown:
            self.progressIndicator.alpha = 1;
            self.progressIndicatorControl.userInteractionEnabled = YES;
            [self setNeedsLayout];
            break;
            
        case VideoTrimmerProgressIndicatorModeHiddenOnlyWhenTrimming:
            self.progressIndicator.alpha = (self.trimmingState == VideoTrimmerTrimmingStateNone) ? 1 : 0;
            self.progressIndicatorControl.userInteractionEnabled = (self.trimmingState == VideoTrimmerTrimmingStateNone);
            if (self.trimmingState == VideoTrimmerTrimmingStateNone) {
                [self setNeedsLayout];
                if ([UIView inheritedAnimationDuration] > 0) {
                    [UIView performWithoutAnimation:^{
                        [self layoutIfNeeded];
                    }];
                }
            }
            break;
    }
    self.progressIndicatorControl.alpha = self.progressIndicator.alpha;
}

#pragma mark - Gesture Handlers

- (void)thumbnailPanned:(UILongPressGestureRecognizer *)sender {
    [self progressGrabberPanned:sender];
}

- (void)progressGrabberPanned:(UILongPressGestureRecognizer *)sender {
    void (^handleChanged)(void) = ^{
        CGPoint location = [sender locationInView:self];
        CMTime time = [self timeForLocation:location.x + self.grabberOffset];
        
        BOOL didClamp = NO;
        if (CMTimeCompare(time, self.selectedRange.start) < 0) {
            time = self.selectedRange.start;
            didClamp = YES;
        }
        if (CMTimeCompare(time, CMTimeRangeGetEnd(self.selectedRange)) > 0) {
            time = CMTimeRangeGetEnd(self.selectedRange);
            didClamp = YES;
        }
        
        if (didClamp && didClamp != self.didClampWhilePanning) {
            [self.impactFeedbackGenerator impactOccurred];
        }
        self.didClampWhilePanning = didClamp;
        
        self.progress = time;
        [self setNeedsLayout];
        [self sendActionsForControlEvents:[VideoTrimmer progressChanged]];
    };
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            if (self.enableHapticFeedback) {
                UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
                [generator selectionChanged];
                self.impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
                [self.impactFeedbackGenerator prepare];
            }
            
            self.didClampWhilePanning = NO;
            self.isScrubbing = YES;
            [self sendActionsForControlEvents:[VideoTrimmer didBeginScrubbing]];
            handleChanged();
            break;
            
        case UIGestureRecognizerStateChanged:
            handleChanged();
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            self.impactFeedbackGenerator = nil;
            self.isScrubbing = NO;
            [self sendActionsForControlEvents:[VideoTrimmer didEndScrubbing]];
            break;
            
        default:
            break;
    }
}

- (void)leadingGrabberPanned:(UILongPressGestureRecognizer *)sender {
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            self.trimmingState = VideoTrimmerTrimmingStateLeading;
            self.grabberOffset = self.thumbView.chevronWidth - [sender locationInView:self.thumbView.leadingGrabber].x;
            
            [self startPanning];
            [self sendActionsForControlEvents:[VideoTrimmer didBeginTrimmingFromStart]];
            break;
            
        case UIGestureRecognizerStateChanged: {
            CGPoint location = [sender locationInView:self];
            CMTime current = [self timeForLocation:location.x + self.grabberOffset];
            CMTime min = CMTimeSubtract(CMTimeRangeGetEnd(self.selectedRange), self.minimumDuration);
            
            BOOL didClamp = NO;
            CMTime endTime = CMTimeRangeGetEnd(self.selectedRange);
            
            // Create range with explicit duration calculation (like Swift CMTimeRange(start:, end:))
            CMTime duration = CMTimeSubtract(endTime, current);
            CMTimeRange newRange = CMTimeRangeMake(current, duration);
            
            if (CMTimeCompare(current, min) != -1) {
                CMTime minDuration = CMTimeSubtract(endTime, min);
                newRange = CMTimeRangeMake(min, minDuration);
                didClamp = YES;
            } else if (CMTimeCompare(newRange.duration, self.maximumDuration) != -1) {
                CMTime time = CMTimeSubtract(endTime, self.maximumDuration);
                newRange = CMTimeRangeMake(time, self.maximumDuration);
                didClamp = YES;
            } else if (CMTimeCompare(newRange.start, self.range.start) != 1) {
                CMTime rangeDuration = CMTimeSubtract(endTime, self.range.start);
                newRange = CMTimeRangeMake(self.range.start, rangeDuration);
                didClamp = YES;
            } else if (CMTimeCompare(newRange.duration, self.minimumDuration) != 1) {
                CMTime minDuration = CMTimeSubtract(endTime, min);
                newRange = CMTimeRangeMake(min, minDuration);
                didClamp = YES;
            }
            
            if (didClamp && didClamp != self.didClampWhilePanning) {
                [self.impactFeedbackGenerator impactOccurred];
            }
            
            self.didClampWhilePanning = didClamp;
            self.selectedRange = newRange;
            [self sendActionsForControlEvents:[VideoTrimmer leadingGrabberChanged]];
            [self setNeedsLayout];
            
           [self startZoomWaitTimer];
            break;
        }
            
        case UIGestureRecognizerStateEnded:
            [self stopPanning];
            [self sendActionsForControlEvents:[VideoTrimmer didEndTrimmingFromStart]];
            break;
            
        case UIGestureRecognizerStateCancelled:
            [self stopPanning];
            break;

        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateFailed:
            break;
            
        default:
            break;
    }
}

- (void)trailingGrabberPanned:(UILongPressGestureRecognizer *)sender {
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            self.trimmingState = VideoTrimmerTrimmingStateTrailing;
            self.grabberOffset = [sender locationInView:self.thumbView.trailingGrabber].x;
            
            [self startPanning];
            [self sendActionsForControlEvents:[VideoTrimmer didBeginTrimmingFromEnd]];
            break;
            
        case UIGestureRecognizerStateChanged: {
            CGPoint location = [sender locationInView:self];
            CMTime current = [self timeForLocation:location.x - self.grabberOffset];
            CMTime min = CMTimeAdd(self.selectedRange.start, self.minimumDuration);
            
            BOOL didClamp = NO;
            CMTime endTime = [self timeForLocation:location.x - self.grabberOffset];
            
            // Create range with explicit duration calculation (like Swift CMTimeRange(start:, end:))
            CMTime duration = CMTimeSubtract(endTime, self.selectedRange.start);
            CMTimeRange newRange = CMTimeRangeMake(self.selectedRange.start, duration);

            
            if (CMTimeCompare(current, min) == -1) {
                CMTime minDuration = CMTimeSubtract(min, self.selectedRange.start);
                newRange = CMTimeRangeMake(self.selectedRange.start, minDuration);
                didClamp = YES;
            } else if (CMTimeCompare(newRange.duration, self.maximumDuration) != -1) {
                newRange = CMTimeRangeMake(self.selectedRange.start, self.maximumDuration);
                didClamp = YES;
            } else if (CMTimeCompare(endTime, CMTimeRangeGetEnd(self.range)) != -1) {
                // prevent endTime to be greater than video endTime
                CMTime maxDuration = CMTimeSubtract(CMTimeRangeGetEnd(self.range), self.selectedRange.start);
                newRange = CMTimeRangeMake(self.selectedRange.start, maxDuration);
                didClamp = YES;
            } else if (CMTimeCompare(newRange.duration, self.minimumDuration) != 1) {
                CMTime minDuration = CMTimeSubtract(min, self.selectedRange.start);
                newRange = CMTimeRangeMake(self.selectedRange.start, minDuration);
                didClamp = YES;
            }
            
            if (didClamp && didClamp != self.didClampWhilePanning) {
                [self.impactFeedbackGenerator impactOccurred];
            }
            
            self.didClampWhilePanning = didClamp;
            self.selectedRange = newRange;
            [self sendActionsForControlEvents:[VideoTrimmer trailingGrabberChanged]];
            [self setNeedsLayout];
            
            [self startZoomWaitTimer];
            break;
        }
            
        case UIGestureRecognizerStateEnded:
            [self stopPanning];
            [self sendActionsForControlEvents:[VideoTrimmer didEndTrimmingFromEnd]];
            break;
            
        case UIGestureRecognizerStateCancelled:
            [self stopPanning];
            break;
            
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateFailed:
            break;
            
        default:
            break;
    }
}

#pragma mark - UIView

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, 50);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGSize size = self.bounds.size;
    CGFloat inset = self.thumbView.chevronWidth;
    CGFloat left = [self locationForTime:self.selectedRange.start] - inset;
    CGFloat right = [self locationForTime:CMTimeRangeGetEnd(self.selectedRange)] + inset;
    
    if (right > self.bounds.size.width) {
        right = self.bounds.size.width + inset * 2;
    }
    
    if (left < 0) {
        left = -inset;
    }
    
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    self.thumbView.frame = CGRectMake(left, 0, MAX(right - left, inset * 2), size.height);
    
    BOOL isZoomedToEnd = (self.trimmingState == VideoTrimmerTrimmingStateLeading && self.isZoomedIn);
    
    CGFloat thumbnailOffset = (self.isZoomedIn ? self.horizontalInset + inset + 6 : 0);
    CGFloat coverOffset = thumbnailOffset - self.horizontalInset;
    CGFloat coverStartOffset = (self.isZoomedIn ? 0 : inset);
    
    CGRect thumbnailRect = CGRectInset(rect, self.horizontalInset - thumbnailOffset, self.thumbView.edgeHeight);
    self.thumbnailWrapperView.frame = thumbnailRect;
    self.thumbnailTrackView.frame = CGRectMake(0, 0, thumbnailRect.size.width - (isZoomedToEnd ? 0 : inset), thumbnailRect.size.height);
    self.thumbnailLeadingCoverView.frame = CGRectMake(coverStartOffset, 0, left + inset * 0.5 + coverOffset - coverStartOffset, thumbnailRect.size.height);
    self.thumbnailTrailingCoverView.frame = CGRectMake(right - inset * 0.5 + coverOffset, 0, thumbnailRect.size.width - coverStartOffset - (right - inset * 0.5 + coverOffset), thumbnailRect.size.height);
    
    if (self.progressIndicator.alpha > 0) {
        CGFloat progressWidth = 4;
        CGFloat progressIndicatorOffset = [self locationForTime:self.progress];
        CGFloat progressLeft = MIN(MAX(CGRectGetMinX(self.thumbView.frame) + inset, progressIndicatorOffset - progressWidth * 0.5), CGRectGetMaxX(self.thumbView.frame) - inset - progressWidth);
        self.progressIndicator.frame = CGRectMake(progressLeft, CGRectGetMinY(thumbnailRect), progressWidth, thumbnailRect.size.height);
        
        CGFloat progressControlWidth = 24;
        
        CGFloat progressControlLeft = MAX(CGRectGetMinX(self.thumbView.frame) + inset, progressLeft);
        CGFloat progressControlRight = progressLeft + progressControlWidth;
        if (progressControlRight > CGRectGetMaxX(self.thumbView.frame) - inset) {
            progressControlRight = CGRectGetMaxX(self.thumbView.frame) - inset;
            progressControlLeft = MAX(CGRectGetMinX(self.thumbView.frame) + inset, progressControlRight - progressControlWidth);
        }
        self.progressIndicatorControl.frame = CGRectMake(progressControlLeft, CGRectGetMinY(thumbnailRect), progressControlRight - progressControlLeft, thumbnailRect.size.height);
    }
    
    [self regenerateThumbnailsIfNeeded];
    
    for (VideoTrimmerThumbnail *thumbnail in self.thumbnails) {
        CGFloat position = [self locationForTime:thumbnail.time] - self.horizontalInset + thumbnailOffset;
        CGRect frame = CGRectMake(position, 0, self.thumbnailSize.width, self.thumbnailSize.height);
        if (thumbnail.imageView.bounds.size.width == 0) {
            [UIView performWithoutAnimation:^{
                thumbnail.imageView.frame = frame;
            }];
        } else {
            thumbnail.imageView.frame = frame;
        }
    }
}

@end
