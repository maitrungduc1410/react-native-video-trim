#import "VideoTrimmerThumb.h"

@interface VideoTrimmerThumb ()
// Redeclare readonly properties as readwrite for internal use
@property (nonatomic, strong, readwrite) UIImageView *leadingChevronImageView;
@property (nonatomic, strong, readwrite) UIImageView *trailingChevronView;
@property (nonatomic, strong, readwrite) UIView *wrapperView;
@property (nonatomic, strong, readwrite) UIView *leadingView;
@property (nonatomic, strong, readwrite) UIView *trailingView;
@property (nonatomic, strong, readwrite) UIView *topView;
@property (nonatomic, strong, readwrite) UIView *bottomView;
@property (nonatomic, strong, readwrite) UIControl *leadingGrabber;
@property (nonatomic, strong, readwrite) UIControl *trailingGrabber;
@end

@implementation VideoTrimmerThumb

- (CGFloat)chevronWidth {
    return 16;
}

- (CGFloat)edgeHeight {
    return 4;
}

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

- (void)setup {
    // Initialize leading chevron image view
    self.leadingChevronImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.compact.left"]];
    self.leadingChevronImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.leadingChevronImageView.tintColor = [UIColor blackColor];
    self.leadingChevronImageView.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
    self.leadingChevronImageView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Initialize trailing chevron image view
    self.trailingChevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.compact.right"]];
    self.trailingChevronView.contentMode = UIViewContentModeScaleAspectFill;
    self.trailingChevronView.tintColor = [UIColor blackColor];
    self.trailingChevronView.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
    self.trailingChevronView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Initialize wrapper view
    self.wrapperView = [[UIView alloc] init];
    self.wrapperView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Initialize leading view
    self.leadingView = [[UIView alloc] init];
    self.leadingView.layer.cornerRadius = 6;
    if (@available(iOS 13.0, *)) {
        self.leadingView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.leadingView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMinXMinYCorner;
    self.leadingView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Initialize trailing view
    self.trailingView = [[UIView alloc] init];
    self.trailingView.layer.cornerRadius = 6;
    if (@available(iOS 13.0, *)) {
        self.trailingView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.trailingView.layer.maskedCorners = kCALayerMaxXMaxYCorner | kCALayerMaxXMinYCorner;
    self.trailingView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Initialize top view
    self.topView = [[UIView alloc] init];
    self.topView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Initialize bottom view
    self.bottomView = [[UIView alloc] init];
    self.bottomView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Initialize grabber controls
    self.leadingGrabber = [[UIControl alloc] init];
    self.leadingGrabber.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.trailingGrabber = [[UIControl alloc] init];
    self.trailingGrabber.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Set up view hierarchy
    [self.leadingView addSubview:self.leadingChevronImageView];
    [self.trailingView addSubview:self.trailingChevronView];
    
    [self.wrapperView addSubview:self.leadingView];
    [self.wrapperView addSubview:self.trailingView];
    [self.wrapperView addSubview:self.topView];
    [self.wrapperView addSubview:self.bottomView];
    [self addSubview:self.wrapperView];
    
    [self.wrapperView addSubview:self.leadingGrabber];
    [self.wrapperView addSubview:self.trailingGrabber];
    
    [self setupConstraints];
    [self updateColor];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Wrapper view constraints
        [self.wrapperView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.wrapperView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.wrapperView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.wrapperView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        
        // Leading view constraints
        [self.leadingView.topAnchor constraintEqualToAnchor:self.wrapperView.topAnchor],
        [self.leadingView.bottomAnchor constraintEqualToAnchor:self.wrapperView.bottomAnchor],
        [self.leadingView.leadingAnchor constraintEqualToAnchor:self.wrapperView.leadingAnchor],
        [self.leadingView.widthAnchor constraintEqualToConstant:self.chevronWidth],
        
        // Trailing view constraints
        [self.trailingView.topAnchor constraintEqualToAnchor:self.wrapperView.topAnchor],
        [self.trailingView.bottomAnchor constraintEqualToAnchor:self.wrapperView.bottomAnchor],
        [self.trailingView.trailingAnchor constraintEqualToAnchor:self.wrapperView.trailingAnchor],
        [self.trailingView.widthAnchor constraintEqualToConstant:self.chevronWidth],
        
        // Top view constraints
        [self.topView.topAnchor constraintEqualToAnchor:self.wrapperView.topAnchor],
        [self.topView.leadingAnchor constraintEqualToAnchor:self.leadingView.trailingAnchor],
        [self.topView.trailingAnchor constraintEqualToAnchor:self.trailingView.leadingAnchor],
        [self.topView.heightAnchor constraintEqualToConstant:self.edgeHeight],
        
        // Bottom view constraints
        [self.bottomView.bottomAnchor constraintEqualToAnchor:self.wrapperView.bottomAnchor],
        [self.bottomView.leadingAnchor constraintEqualToAnchor:self.leadingView.trailingAnchor],
        [self.bottomView.trailingAnchor constraintEqualToAnchor:self.trailingView.leadingAnchor],
        [self.bottomView.heightAnchor constraintEqualToConstant:self.edgeHeight],
        
        // Leading Chevron ImageView constraints
        [self.leadingChevronImageView.topAnchor constraintEqualToAnchor:self.leadingView.topAnchor constant:8],
        [self.leadingChevronImageView.bottomAnchor constraintEqualToAnchor:self.leadingView.bottomAnchor constant:-8],
        [self.leadingChevronImageView.leadingAnchor constraintEqualToAnchor:self.leadingView.leadingAnchor constant:2],
        [self.leadingChevronImageView.trailingAnchor constraintEqualToAnchor:self.leadingView.trailingAnchor constant:-2],
        
        // Trailing Chevron ImageView constraints
        [self.trailingChevronView.topAnchor constraintEqualToAnchor:self.trailingView.topAnchor constant:8],
        [self.trailingChevronView.bottomAnchor constraintEqualToAnchor:self.trailingView.bottomAnchor constant:-8],
        [self.trailingChevronView.leadingAnchor constraintEqualToAnchor:self.trailingView.leadingAnchor constant:2],
        [self.trailingChevronView.trailingAnchor constraintEqualToAnchor:self.trailingView.trailingAnchor constant:-2],
        
        // Leading Grabber constraints
        [self.leadingGrabber.topAnchor constraintEqualToAnchor:self.leadingView.topAnchor],
        [self.leadingGrabber.bottomAnchor constraintEqualToAnchor:self.leadingView.bottomAnchor],
        [self.leadingGrabber.leadingAnchor constraintEqualToAnchor:self.leadingView.leadingAnchor],
        [self.leadingGrabber.trailingAnchor constraintEqualToAnchor:self.leadingView.trailingAnchor],
        
        // Trailing Grabber constraints
        [self.trailingGrabber.topAnchor constraintEqualToAnchor:self.trailingView.topAnchor],
        [self.trailingGrabber.bottomAnchor constraintEqualToAnchor:self.trailingView.bottomAnchor],
        [self.trailingGrabber.leadingAnchor constraintEqualToAnchor:self.trailingView.leadingAnchor],
        [self.trailingGrabber.trailingAnchor constraintEqualToAnchor:self.trailingView.trailingAnchor]
    ]];
}

- (void)updateColor {
    UIColor *color = [UIColor systemYellowColor];
    self.leadingView.backgroundColor = color;
    self.trailingView.backgroundColor = color;
    self.topView.backgroundColor = color;
    self.bottomView.backgroundColor = color;
}

@end
