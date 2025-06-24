#import <UIKit/UIKit.h>

@interface VideoTrimmerThumb : UIView

// Properties for dimensions
@property (nonatomic, assign, readonly) CGFloat chevronWidth;
@property (nonatomic, assign, readonly) CGFloat edgeHeight;

// Grabber controls for interaction
@property (nonatomic, strong, readonly) UIControl *leadingGrabber;
@property (nonatomic, strong, readonly) UIControl *trailingGrabber;

// UI Components (readonly access)
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, strong, readonly) UIImageView *leadingChevronImageView;
@property (nonatomic, strong, readonly) UIImageView *trailingChevronView;
@property (nonatomic, strong, readonly) UIView *wrapperView;
@property (nonatomic, strong, readonly) UIView *leadingView;
@property (nonatomic, strong, readonly) UIView *trailingView;
@property (nonatomic, strong, readonly) UIView *topView;
@property (nonatomic, strong, readonly) UIView *bottomView;

@end
