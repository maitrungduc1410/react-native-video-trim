#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <VideoTrimSpec/VideoTrimSpec.h>

@class VideoTrimmer;

@interface VideoTrimmerViewController : UIViewController

// Main properties
@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, copy) void (^cancelBtnClicked)(void);
@property (nonatomic, copy) void (^saveBtnClicked)(CMTimeRange selectedRange);

// UI Components
@property (nonatomic, strong) VideoTrimmer *trimmer;
@property (nonatomic, strong) UIStackView *timingStackView;
@property (nonatomic, strong) UILabel *leadingTrimLabel;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *trailingTrimLabel;
@property (nonatomic, strong) UIStackView *btnStackView;
@property (nonatomic, strong) UIButton *cancelBtn;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIButton *saveBtn;
@property (nonatomic, strong) AVPlayerViewController *playerController;
@property (nonatomic, strong) UIView *headerView;

// Configuration properties
@property (nonatomic, strong) NSString *cancelButtonText;
@property (nonatomic, strong) NSString *saveButtonText;
@property (nonatomic, strong) NSString *headerText;
@property (nonatomic, assign) NSInteger headerTextSize;
@property (nonatomic, assign) double headerTextColor;
@property (nonatomic, assign) BOOL autoplay;
@property (nonatomic, assign) double jumpToPositionOnLoad;
@property (nonatomic, assign) BOOL enableHapticFeedback;
@property (nonatomic, assign) NSInteger maximumDuration;
@property (nonatomic, assign) NSInteger minimumDuration;

// Player state properties
@property (nonatomic, strong, readonly) AVPlayer *player;
@property (nonatomic, strong) id timeObserverToken;
@property (nonatomic, assign) BOOL isSeekInProgress;
@property (nonatomic, assign) CMTime chaseTime;

// Methods
- (void)configureWithConfig:(JS::NativeVideoTrim::EditorConfig)config;
- (void)onAssetFailToLoad;
- (void)pausePlayer;

@end
