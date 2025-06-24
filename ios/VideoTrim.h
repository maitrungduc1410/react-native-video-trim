#import <VideoTrimSpec/VideoTrimSpec.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "AssetLoader.h"

@class VideoTrimmerViewController;
@class ProgressAlertController;

@interface VideoTrim : NativeVideoTrimSpecBase <NativeVideoTrimSpec, AssetLoaderDelegate, UIDocumentPickerDelegate>

@property (nonatomic, strong) NSString *FILE_PREFIX;
@property (nonatomic, strong) NSString *BEFORE_TRIM_PREFIX;
@property (nonatomic, assign) BOOL isShowing;
@property (nonatomic, strong) VideoTrimmerViewController *vc;
@property (nonatomic, strong) NSURL *outputFile;
@property (nonatomic, assign) BOOL isVideoType;
//@property (nonatomic, assign) JS::NativeVideoTrim::EditorConfig editorConfig;

// Helper methods
- (NSURL *)renameFileAtURL:(NSURL *)url newName:(NSString *)newName;
- (void)trimWithViewController:(VideoTrimmerViewController *)viewController
                     inputFile:(NSURL *)inputFile 
                 videoDuration:(double)videoDuration 
                     startTime:(double)startTime 
                       endTime:(double)endTime;
- (void)saveFileToFilesApp:(NSURL *)fileURL;
- (void)shareFile:(NSURL *)fileURL;
- (int)deleteFileAtURL:(NSURL *)url;
- (void)onError:(NSString *)message code:(NSString *)code;

@end
