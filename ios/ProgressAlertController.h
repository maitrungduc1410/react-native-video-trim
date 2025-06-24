#import <UIKit/UIKit.h>

@interface ProgressAlertController : UIViewController

@property (nonatomic, copy) void (^onDismiss)(void);

- (void)setTitle:(NSString *)text;
- (void)setCancelTitle:(NSString *)text;
- (void)setProgress:(float)progress;
- (void)showCancelBtn;

@end
