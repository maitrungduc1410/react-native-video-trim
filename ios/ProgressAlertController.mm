#import "ProgressAlertController.h"

@implementation ProgressAlertController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupBackground];
    [self setupAlertView];
}

- (void)setupBackground {
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
}

- (void)setupAlertView {
    UIView *alertView = [[UIView alloc] init];
    alertView.backgroundColor = [UIColor colorWithRed:28/255.0 green:28/255.0 blue:30/255.0 alpha:1.0];
    alertView.layer.cornerRadius = 12;
    alertView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:alertView];
    [NSLayoutConstraint activateConstraints:@[
        [alertView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [alertView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [alertView.widthAnchor constraintEqualToConstant:270]
    ]];
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.font = [UIFont systemFontOfSize:18];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.textColor = [UIColor whiteColor];
    [alertView addSubview:self.titleLabel];
    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    [alertView addSubview:self.progressBar];
    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.actionButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [self.actionButton setTitleColor:[UIColor systemPinkColor] forState:UIControlStateNormal];
    self.actionButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.actionButton addTarget:self action:@selector(dismissAlert) forControlEvents:UIControlEventTouchUpInside];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionButton.hidden = YES;
    [alertView addSubview:self.actionButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:alertView.topAnchor constant:16],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:alertView.leadingAnchor constant:16],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:alertView.trailingAnchor constant:-16],
        [self.progressBar.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:16],
        [self.progressBar.leadingAnchor constraintEqualToAnchor:alertView.leadingAnchor constant:16],
        [self.progressBar.trailingAnchor constraintEqualToAnchor:alertView.trailingAnchor constant:-16],
        [self.actionButton.topAnchor constraintEqualToAnchor:self.progressBar.bottomAnchor constant:16],
        [self.actionButton.bottomAnchor constraintEqualToAnchor:alertView.bottomAnchor constant:-16],
        [self.actionButton.centerXAnchor constraintEqualToAnchor:alertView.centerXAnchor]
    ]];
}

- (void)dismissAlert {
    if (self.onDismiss) self.onDismiss();
}

- (void)setTitle:(NSString *)text {
    self.titleLabel.text = text;
}

- (void)setCancelTitle:(NSString *)text {
    [self.actionButton setTitle:text forState:UIControlStateNormal];
}

- (void)setProgress:(float)progress {
    [self.progressBar setProgress:progress animated:YES];
}

- (void)showCancelBtn {
    [self.view layoutIfNeeded];
    self.actionButton.hidden = NO;
}

@end
