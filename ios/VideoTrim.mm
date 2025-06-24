#import "VideoTrim.h"
#import "ProgressAlertController.h"
#import "VideoTrimmerViewController.h"
#import "AssetLoader.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTUtils.h>
#import <React/RCTConvert.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import <ffmpegkit/FFmpegKit.h>
#import <ffmpegkit/FFmpegKitConfig.h>

@implementation VideoTrim {
    std::optional<JS::NativeVideoTrim::EditorConfig> _editorConfig;
}

RCT_EXPORT_MODULE()

- (instancetype)init {
    if (self = [super init]) {
        self.FILE_PREFIX = @"trimmedVideo";
        self.BEFORE_TRIM_PREFIX = @"beforeTrim";
        self.isShowing = NO;
        self.vc = nil;
        self.outputFile = nil;
        self.isVideoType = YES;
        
    }
    return self;
}

// Add custom getter and setter
- (JS::NativeVideoTrim::EditorConfig)editorConfig {
    if (_editorConfig.has_value()) {
        return _editorConfig.value();
    }
    // This shouldn't happen if properly initialized
    @throw [NSException exceptionWithName:@"EditorConfigNotInitialized"
                                   reason:@"EditorConfig accessed before initialization"
                                 userInfo:nil];
}

- (void)setEditorConfig:(JS::NativeVideoTrim::EditorConfig)config {
    _editorConfig = config;
}

- (void)cleanFiles:(nonnull RCTPromiseResolveBlock)resolve reject:(nonnull RCTPromiseRejectBlock)reject { 
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSError *error = nil;
    NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:documentsDirectory includingPropertiesForKeys:nil options:0 error:&error];
    int successCount = 0;
    for (NSURL *fileURL in directoryContents) {
        NSString *last = [fileURL lastPathComponent];
        if ([last hasPrefix:self.FILE_PREFIX] || [last hasPrefix:self.BEFORE_TRIM_PREFIX]) {
            NSError *removeError = nil;
            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:&removeError];
            if (!removeError) {
                successCount++;
            }
        }
    }
    resolve(@(successCount));
}

- (void)closeEditor { 
    if (!self.vc) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.vc dismissViewControllerAnimated:YES completion:^{
            [self emitOnHide];
            self.isShowing = NO;
        }];
    });
}

- (void)deleteFile:(nonnull NSString *)filePath resolve:(nonnull RCTPromiseResolveBlock)resolve reject:(nonnull RCTPromiseRejectBlock)reject { 
    NSURL *url = [NSURL URLWithString:filePath];
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
        if (error) {
            NSLog(@"[deleteFile] Error: %@", error);
            reject(@"delete_file_error", @"Failed to delete file", error);
            resolve(@(NO));
            return;
        }
        resolve(@(YES));
        return;
    }
    resolve(@(NO));
}

- (void)isValidFile:(nonnull NSString *)url resolve:(nonnull RCTPromiseResolveBlock)resolve reject:(nonnull RCTPromiseRejectBlock)reject { 
    NSURL *fileURL = [NSURL URLWithString:url];
    AVAsset *asset = [AVAsset assetWithURL:fileURL];
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    BOOL isValid = (videoTracks.count > 0 || audioTracks.count > 0);
    NSString *fileType = videoTracks.count > 0 ? @"video" : (audioTracks.count > 0 ? @"audio" : @"unknown");
    double durationMs = CMTimeGetSeconds(asset.duration) * 1000;
    NSDictionary *result = @{ @"isValid": @(isValid), @"fileType": fileType, @"duration": @(isValid ? durationMs : -1) };
    resolve(result);
}

- (void)listFiles:(nonnull RCTPromiseResolveBlock)resolve reject:(nonnull RCTPromiseRejectBlock)reject { 
    NSMutableArray *files = [NSMutableArray array];
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSError *error = nil;
    NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:documentsDirectory includingPropertiesForKeys:nil options:0 error:&error];
    if (error) {
        NSLog(@"[listFiles] Error: %@", error);
        reject(@"list_files_error", @"Failed to list files", error);
        return;
    }
    for (NSURL *fileURL in directoryContents) {
        NSString *last = [fileURL lastPathComponent];
        if ([last hasPrefix:self.FILE_PREFIX] || [last hasPrefix:self.BEFORE_TRIM_PREFIX]) {
            [files addObject:[fileURL absoluteString]];
        }
    }
    resolve(files);
}

- (void)showEditor:(nonnull NSString *)filePath config:(JS::NativeVideoTrim::EditorConfig &)config {
    if (self.isShowing) return;
    
    self.editorConfig = config;
    self.isVideoType = [config.type() isEqualToString:@"video"];
    
    NSURL *destPath = nil;
    
    if ([filePath hasPrefix:@"http://"] || [filePath hasPrefix:@"https://"]) {
        destPath = [NSURL URLWithString:filePath];
    } else {
        NSLog(@"before rename");
        destPath = [self renameFileAtURL:[NSURL URLWithString:filePath] newName:self.BEFORE_TRIM_PREFIX];
    }
    
    if (!destPath) {
        [self onError:@"Fail to rename file" code:@"INVALID_FILE_PATH"];
        self.isShowing = NO;
        return;
    }
    
    NSLog(@"✅ destPath created: %@", destPath);

    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.vc = [[VideoTrimmerViewController alloc] init];
        if (!self.vc) return;
        
        [self.vc configureWithConfig:self.editorConfig];
        
        __weak __typeof__(self) weakSelf = self;
        
        self.vc.cancelBtnClicked = ^{
            if (!weakSelf.editorConfig.enableCancelDialog()) {
                [weakSelf emitOnCancel];
                [weakSelf.vc dismissViewControllerAnimated:YES completion:^{
                    [weakSelf emitOnHide];
                    weakSelf.isShowing = NO;
                }];
                return;
            }
            
            UIAlertController *dialogMessage = [UIAlertController alertControllerWithTitle:weakSelf.editorConfig.cancelDialogTitle()
                                                                                   message:weakSelf.editorConfig.cancelDialogMessage()
                                                                            preferredStyle:UIAlertControllerStyleAlert];
            dialogMessage.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            
            UIAlertAction *ok = [UIAlertAction actionWithTitle:weakSelf.editorConfig.cancelDialogConfirmText()
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                [weakSelf emitOnCancel];
                [weakSelf.vc dismissViewControllerAnimated:YES completion:^{
                    [weakSelf emitOnHide];
                    weakSelf.isShowing = NO;
                }];
            }];
            
            UIAlertAction *cancel = [UIAlertAction actionWithTitle:weakSelf.editorConfig.cancelDialogCancelText()
                                                             style:UIAlertActionStyleCancel
                                                           handler:nil];
            
            [dialogMessage addAction:ok];
            [dialogMessage addAction:cancel];
            
            UIViewController *root = RCTPresentedViewController();
            if (root) {
                [root presentViewController:dialogMessage animated:YES completion:nil];
            }
        };
        
        self.vc.saveBtnClicked = ^(CMTimeRange selectedRange) {
            if (!weakSelf.editorConfig.enableSaveDialog()) {
                [weakSelf trimWithViewController:weakSelf.vc
                                       inputFile:destPath
                                   videoDuration:CMTimeGetSeconds(weakSelf.vc.asset.duration)
                                       startTime:CMTimeGetSeconds(selectedRange.start)
                                         endTime:CMTimeGetSeconds(CMTimeRangeGetEnd(selectedRange))];
                return;
            }
            
            UIAlertController *dialogMessage = [UIAlertController alertControllerWithTitle:weakSelf.editorConfig.saveDialogTitle()
                                                                                   message:weakSelf.editorConfig.saveDialogMessage()
                                                                            preferredStyle:UIAlertControllerStyleAlert];
            dialogMessage.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            
            UIAlertAction *ok = [UIAlertAction actionWithTitle:weakSelf.editorConfig.saveDialogConfirmText()
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
                [weakSelf trimWithViewController:weakSelf.vc
                                       inputFile:destPath
                                   videoDuration:CMTimeGetSeconds(weakSelf.vc.asset.duration)
                                       startTime:CMTimeGetSeconds(selectedRange.start)
                                         endTime:CMTimeGetSeconds(CMTimeRangeGetEnd(selectedRange))];
            }];
            
            UIAlertAction *cancel = [UIAlertAction actionWithTitle:weakSelf.editorConfig.saveDialogCancelText()
                                                             style:UIAlertActionStyleCancel
                                                           handler:nil];
            
            [dialogMessage addAction:ok];
            [dialogMessage addAction:cancel];
            
            UIViewController *root = RCTPresentedViewController();
            if (root) {
                [root presentViewController:dialogMessage animated:YES completion:nil];
            }
        };
        
        self.vc.modalInPresentation = YES;
        
        if (self.editorConfig.fullScreenModalIOS()) {
            self.vc.modalPresentationStyle = UIModalPresentationFullScreen;
        }
        
        UIViewController *root = RCTPresentedViewController();
        if (root) {
            [root presentViewController:self.vc animated:YES completion:^{
                [self emitOnShow];
                self.isShowing = YES;
                
                AssetLoader *assetLoader = [[AssetLoader alloc] init];
                assetLoader.delegate = self;
                NSLog(@"🔄 Starting to load asset from: %@", destPath);
                [assetLoader loadAssetWithURL:destPath isVideoType:self.isVideoType];
            }];
        }
    });
}

- (void)trim:(nonnull NSString *)url options:(JS::NativeVideoTrim::TrimOptions &)options resolve:(nonnull RCTPromiseResolveBlock)resolve reject:(nonnull RCTPromiseRejectBlock)reject { 
    NSURL *inputURL = [NSURL URLWithString:url];
    if (!inputURL) {
        reject(@"INVALID_URL", @"Invalid input URL", nil);
        return;
    }
    
    // Create output file
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    NSString *outputName = [NSString stringWithFormat:@"%@_%d.%@", self.FILE_PREFIX, (int)timestamp, options.outputExt()];
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *outputURL = [documentsDirectory URLByAppendingPathComponent:outputName];
    
    // Prepare FFmpeg command
    NSMutableArray *cmds = [NSMutableArray arrayWithObjects:
        @"-ss", [NSString stringWithFormat:@"%.3f", options.startTime() / 1000.0],
        @"-to", [NSString stringWithFormat:@"%.3f", options.endTime() / 1000.0],
        @"-i", inputURL.absoluteString,
        @"-c", @"copy",
        outputURL.absoluteString, nil];
    
    [FFmpegKit executeWithArgumentsAsync:cmds
                      withCompleteCallback:^(FFmpegSession* session) {
        SessionState state = [session getState];
        ReturnCode *returnCode = [session getReturnCode];
        
        if ([ReturnCode isSuccess:returnCode]) {
            NSDictionary *result = @{
                @"outputPath": outputURL.absoluteString,
                @"startTime": [NSNumber numberWithDouble:options.startTime()],
                @"endTime": [NSNumber numberWithDouble:options.endTime()]
            };
            resolve(result);
        } else {
            NSString *errorMessage = [NSString stringWithFormat:@"Trimming failed with state %@ and rc %@", 
                                    [FFmpegKitConfig sessionStateToString:state], 
                                    returnCode];
            reject(@"TRIMMING_FAILED", errorMessage, nil);
        }
    } withLogCallback:nil withStatisticsCallback:nil];
}

- (void)trimWithViewController:(VideoTrimmerViewController *)viewController 
                     inputFile:(NSURL *)inputFile 
                 videoDuration:(double)videoDuration 
                     startTime:(double)startTime 
                       endTime:(double)endTime {
    [self.vc pausePlayer];
    
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    NSString *outputName = [NSString stringWithFormat:@"%@_%d.%@", self.FILE_PREFIX, (int)timestamp, self.editorConfig.outputExt()];
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    self.outputFile = [documentsDirectory URLByAppendingPathComponent:outputName];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ";
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    NSString *dateTime = [formatter stringFromDate:[NSDate date]];
    
    [self emitOnStartTrimming];
    
    __block FFmpegSession *ffmpegSession = nil;
    ProgressAlertController *progressAlert = [[ProgressAlertController alloc] init];
    progressAlert.modalPresentationStyle = UIModalPresentationOverFullScreen;
    progressAlert.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [progressAlert setTitle:self.editorConfig.trimmingText()];
    
    if (self.editorConfig.enableCancelTrimming()) {
        [progressAlert setCancelTitle:self.editorConfig.cancelTrimmingButtonText()];
        [progressAlert showCancelBtn];
        __weak __typeof__(progressAlert) weakProgressAlert = progressAlert;

        progressAlert.onDismiss = ^{
            if (self.editorConfig.enableCancelTrimmingDialog()) {
                UIAlertController *dialogMessage = [UIAlertController alertControllerWithTitle:self.editorConfig.cancelTrimmingDialogTitle()
                                                                                       message:self.editorConfig.cancelTrimmingDialogMessage()
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                dialogMessage.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
                
                UIAlertAction *ok = [UIAlertAction actionWithTitle:self.editorConfig.cancelTrimmingDialogConfirmText()
                                                             style:UIAlertActionStyleDestructive
                                                           handler:^(UIAlertAction *action) {
                    if (ffmpegSession) {
                        [ffmpegSession cancel];
                    } else {
                        [self emitOnCancelTrimming];
                    }
                    [weakProgressAlert dismissViewControllerAnimated:YES completion:nil];
                }];
                
                UIAlertAction *cancel = [UIAlertAction actionWithTitle:self.editorConfig.cancelTrimmingDialogCancelText()
                                                                 style:UIAlertActionStyleCancel
                                                               handler:nil];
                
                [dialogMessage addAction:ok];
                [dialogMessage addAction:cancel];
                
                UIViewController *root = RCTPresentedViewController();
                if (root) {
                    [root presentViewController:dialogMessage animated:YES completion:nil];
                }
            } else {
                if (ffmpegSession) {
                    [ffmpegSession cancel];
                } else {
                    [self emitOnCancelTrimming];
                }
                [weakProgressAlert dismissViewControllerAnimated:YES completion:nil];
            }
        };
    }
    
    UIViewController *root = RCTPresentedViewController();
    if (root) {
        [root presentViewController:progressAlert animated:YES completion:nil];
    }
    
    NSMutableArray *cmds = [NSMutableArray arrayWithObjects:
        @"-ss", [NSString stringWithFormat:@"%.0fms", startTime * 1000],
        @"-to", [NSString stringWithFormat:@"%.0fms", endTime * 1000], nil];
    
    if (self.editorConfig.enableRotation()) {
        [cmds addObjectsFromArray:@[
            @"-display_rotation", [NSString stringWithFormat:@"%.0f", self.editorConfig.rotationAngle()]
        ]];
    }
    
    [cmds addObjectsFromArray:@[
        @"-i", inputFile.absoluteString,
        @"-c", @"copy",
        @"-metadata", [NSString stringWithFormat:@"creation_time=%@", dateTime],
        self.outputFile.absoluteString
    ]];
    
    NSLog(@"Command: %@", [cmds componentsJoinedByString:@" "]);
    
    NSDictionary *eventPayload = @{ @"command": [cmds componentsJoinedByString:@" "] };

    [self emitOnLog:eventPayload];
    
    ffmpegSession = [FFmpegKit executeWithArgumentsAsync:cmds
                                      withCompleteCallback:^(FFmpegSession* session) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    SessionState state = [session getState];
                    ReturnCode *returnCode = [session getReturnCode];
                    
                    if ([ReturnCode isSuccess:returnCode]) {
                        NSDictionary *eventPayload = @{
                            @"outputPath": self.outputFile.absoluteString,
                            @"startTime": [NSString stringWithFormat:@"%.0f", startTime * 1000],
                            @"endTime": [NSString stringWithFormat:@"%.0f", endTime * 1000],
                            @"duration": [NSString stringWithFormat:@"%.0f", videoDuration * 1000]
                        };
                        [self emitOnFinishTrimming:eventPayload];
                        
                        if (self.editorConfig.saveToPhoto() && self.isVideoType) {
                            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                                if (status != PHAuthorizationStatusAuthorized) {
                                    [self onError:@"Permission to access Photo Library is not granted" code:@"NO_PHOTO_PERMISSION"];
                                    return;
                                }
                                
                                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                    PHAssetChangeRequest *request = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:self.outputFile];
                                    request.creationDate = [NSDate date];
                                } completionHandler:^(BOOL success, NSError *error) {
                                    if (success) {
                                        NSLog(@"Edited video saved to Photo Library successfully.");
                                        if (self.editorConfig.removeAfterSavedToPhoto()) {
                                            [self deleteFileAtURL:self.outputFile];
                                        }
                                    } else {
                                        [self onError:[NSString stringWithFormat:@"Failed to save edited video to Photo Library: %@", error.localizedDescription ?: @"Unknown error"] code:@"FAIL_TO_SAVE_TO_PHOTO"];
                                        if (self.editorConfig.removeAfterFailedToSavePhoto()) {
                                            [self deleteFileAtURL:self.outputFile];
                                        }
                                    }
                                }];
                            }];
                        } else if (self.editorConfig.openDocumentsOnFinish()) {
                            [self saveFileToFilesApp:self.outputFile];
                            return;
                        } else if (self.editorConfig.openShareSheetOnFinish()) {
                            [self shareFile:self.outputFile];
                            return;
                        }
                        
                        if (self.editorConfig.closeWhenFinish()) {
                            [self closeEditor];
                        }
                        
                    } else if ([ReturnCode isCancel:returnCode]) {
                        [self emitOnCancelTrimming];
                    } else {
                        NSString *errorMessage = [NSString stringWithFormat:@"Command failed with state %@ and rc %@.%@", 
                                                [FFmpegKitConfig sessionStateToString:state], 
                                                returnCode, 
                                                [session getFailStackTrace] ?: @""];
                        [self onError:errorMessage code:@"TRIMMING_FAILED"];
                        if (self.editorConfig.closeWhenFinish()) {
                            [self closeEditor];
                        }
                    }
                });
            }];
        });
    } withLogCallback:^(Log* log) {
        NSLog(@"FFmpeg process started with log %@", [log getMessage]);
        NSDictionary *eventPayload = @{
            @"level": @([log getLevel]),
            @"message": [log getMessage] ?: @"",
            @"sessionId": @([log getSessionId])
        };
        [self emitOnLog:eventPayload];
    } withStatisticsCallback:^(Statistics* statistics) {
        int timeInMilliseconds = [statistics getTime];
        if (timeInMilliseconds > 0) {
            double completePercentage = timeInMilliseconds / (videoDuration * 1000);
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressAlert setProgress:(float)completePercentage];
            });
        }
        
        NSDictionary *eventPayload = @{
            @"sessionId": @([statistics getSessionId]),
            @"videoFrameNumber": @([statistics getVideoFrameNumber]),
            @"videoFps": @([statistics getVideoFps]),
            @"videoQuality": @([statistics getVideoQuality]),
            @"size": @([statistics getSize]),
            @"time": @([statistics getTime]),
            @"bitrate": @([statistics getBitrate]),
            @"speed": @([statistics getSpeed])
        };
        [self emitOnStatistics:eventPayload];
    }];
}

- (void)saveFileToFilesApp:(NSURL *)fileURL {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithURL:fileURL inMode:UIDocumentPickerModeExportToService];
        documentPicker.delegate = self;
        documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
        
        UIViewController *root = RCTPresentedViewController();
        if (root) {
            [root presentViewController:documentPicker animated:YES completion:nil];
        }
    });
}

- (void)shareFile:(NSURL *)fileURL {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
        
        activityViewController.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *error) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"Sharing error: %@", error.localizedDescription];
                NSLog(@"%@", message);
                [self onError:message code:@"FAIL_TO_SHARE"];
                
                if (self.editorConfig.removeAfterFailedToShare()) {
                    [self deleteFileAtURL:fileURL];
                }
                return;
            }
            
            if (completed) {
                NSLog(@"User completed the sharing activity");
                if (self.editorConfig.removeAfterShared()) {
                    [self deleteFileAtURL:fileURL];
                }
            } else {
                NSLog(@"User cancelled or failed to complete the sharing activity");
                if (self.editorConfig.removeAfterFailedToShare()) {
                    [self deleteFileAtURL:fileURL];
                }
            }
            
            [self closeEditor];
        };
        
        UIViewController *root = RCTPresentedViewController();
        if (root) {
            [root presentViewController:activityViewController animated:YES completion:nil];
        }
    });
}

- (int)deleteFileAtURL:(NSURL *)url {
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
        if (error) {
            NSLog(@"[deleteFile] Error deleting files: %@", error);
            return 2;
        }
        return 0;
    }
    return 1;
}

- (NSURL *)renameFileAtURL:(NSURL *)url newName:(NSString *)newName {
    NSString *fileExtension = url.pathExtension;
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    NSString *newFileName = [NSString stringWithFormat:@"%@_%lld.%@", newName, (long long)timestamp, fileExtension];
    
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                        inDomains:NSUserDomainMask] firstObject];
    NSURL *newURL = [documentsDirectory URLByAppendingPathComponent:newFileName];
    
    NSError *error;
    BOOL success = [[NSFileManager defaultManager] copyItemAtURL:url toURL:newURL error:&error];
    
    if (success) {
        return newURL;
    } else {
        NSLog(@"Failed to rename file: %@", error.localizedDescription);
        return nil;
    }
}

- (void)onError:(NSString *)message code:(NSString *)code {
    NSDictionary *eventPayload = @{
        @"message": message,
        @"errorCode": code
    };
    [self emitOnError:eventPayload];
}

#pragma mark - AssetLoaderDelegate

- (void)assetLoaderDidSucceed:(AssetLoader *)assetLoader {
    NSLog(@"assetLoaderDidSucceed");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.vc) {
            self.vc.asset = assetLoader.asset;
            
            NSDictionary *eventPayload = @{
                @"duration": [NSNumber numberWithFloat:CMTimeGetSeconds(self.vc.asset.duration) * 1000]
            };
            
            [self emitOnLoad:eventPayload];
        }
    });
}

- (void)assetLoader:(AssetLoader *)assetLoader didFailWithError:(NSError *)error forKey:(NSString *)key {
    NSLog(@"❌ Asset loading failed: %@ for key: %@", error.localizedDescription, key);

    NSString *message = [NSString stringWithFormat:@"Failed to load %@: %@", key, error.localizedDescription];

    [self onError:message code:@"FAIL_TO_LOAD_MEDIA"];

    if (self.vc) {
        [self.vc onAssetFailToLoad];
    }

    if (self.editorConfig.alertOnFailToLoad()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *dialogMessage = [UIAlertController alertControllerWithTitle:self.editorConfig.alertOnFailTitle()
                                                                                   message:self.editorConfig.alertOnFailMessage()
                                                                            preferredStyle:UIAlertControllerStyleAlert];
            dialogMessage.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            
            UIAlertAction *ok = [UIAlertAction actionWithTitle:self.editorConfig.alertOnFailCloseText()
                                                         style:UIAlertActionStyleDefault
                                                       handler:nil];
            
            [dialogMessage addAction:ok];
            
            UIViewController *root = RCTPresentedViewController();
            if (root) {
                [root presentViewController:dialogMessage animated:YES completion:nil];
            }
        });
    }
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
//     Handle document picker results if needed
    NSLog(@"Document picker selected URLs: %@", urls);
    
    if (self.editorConfig.removeAfterSavedToDocuments()) {
        [self deleteFileAtURL:self.outputFile];
    }
    
    [self closeEditor];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // Handle document picker cancellation if needed
    NSLog(@"Document picker was cancelled");
    
    if (self.editorConfig.removeAfterFailedToSaveDocuments()) {
        [self deleteFileAtURL:self.outputFile];
    }
    
    [self closeEditor];
}

#pragma mark - TurboModule

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params {
    return std::make_shared<facebook::react::NativeVideoTrimSpecJSI>(params);
}

@end
