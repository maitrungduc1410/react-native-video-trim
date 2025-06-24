#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class VideoTrimmerThumb;

typedef NS_ENUM(NSInteger, VideoTrimmerProgressIndicatorMode) {
    VideoTrimmerProgressIndicatorModeHiddenOnlyWhenTrimming,
    VideoTrimmerProgressIndicatorModeAlwaysShown,
    VideoTrimmerProgressIndicatorModeAlwaysHidden
};

typedef NS_ENUM(NSInteger, VideoTrimmerTrimmingState) {
    VideoTrimmerTrimmingStateNone,
    VideoTrimmerTrimmingStateLeading,
    VideoTrimmerTrimmingStateTrailing
};

@interface VideoTrimmer : UIControl

// Main properties
@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, strong) AVVideoComposition *videoComposition;
@property (nonatomic, assign) CMTime minimumDuration;
@property (nonatomic, assign) CMTime maximumDuration;
@property (nonatomic, assign) BOOL enableHapticFeedback;

// Range properties
@property (nonatomic, assign, readonly) CMTimeRange range;
@property (nonatomic, assign) CMTimeRange selectedRange;

// Progress properties
@property (nonatomic, assign) VideoTrimmerProgressIndicatorMode progressIndicatorMode;
@property (nonatomic, assign) CMTime progress;

// State properties (read-only)
@property (nonatomic, assign, readonly) VideoTrimmerTrimmingState trimmingState;
@property (nonatomic, assign, readonly) BOOL isZoomedIn;
@property (nonatomic, assign, readonly) CMTimeRange zoomedInRange;
@property (nonatomic, assign, readonly) BOOL isScrubbing;

// Computed properties
@property (nonatomic, assign, readonly) CMTimeRange visibleRange;
@property (nonatomic, assign, readonly) CMTime selectedTime;

// Style properties
@property (nonatomic, assign) CGFloat horizontalInset;
@property (nonatomic, strong) UIColor *trackBackgroundColor;
@property (nonatomic, strong) UIColor *thumbRestColor;

// Gesture recognizers (read-only)
@property (nonatomic, strong, readonly) UILongPressGestureRecognizer *leadingGestureRecognizer;
@property (nonatomic, strong, readonly) UILongPressGestureRecognizer *trailingGestureRecognizer;
@property (nonatomic, strong, readonly) UILongPressGestureRecognizer *progressGestureRecognizer;
@property (nonatomic, strong, readonly) UILongPressGestureRecognizer *thumbnailInteractionGestureRecognizer;

// Custom events
+ (UIControlEvents)didBeginTrimmingFromStart;
+ (UIControlEvents)leadingGrabberChanged;
+ (UIControlEvents)didEndTrimmingFromStart;
+ (UIControlEvents)didBeginTrimmingFromEnd;
+ (UIControlEvents)trailingGrabberChanged;
+ (UIControlEvents)didEndTrimmingFromEnd;
+ (UIControlEvents)didBeginScrubbing;
+ (UIControlEvents)progressChanged;
+ (UIControlEvents)didEndScrubbing;

@end
