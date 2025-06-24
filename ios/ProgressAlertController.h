#import <UIKit/UIKit.h>

@interface ProgressAlertController : UIViewController

@property (nonatomic, copy) void (^onDismiss)(void);
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UIButton *actionButton;

- (void)setTitle:(NSString *)title;
- (void)setCancelTitle:(NSString *)title;
- (void)setProgress:(float)progress;
- (void)showCancelBtn;

@end
