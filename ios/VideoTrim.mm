// because Swift class inherits from RCTEventEmitter, hence we need to import it here for both new and old arch
#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED

#import <VideoTrimSpec/VideoTrimSpec.h>
#import <VideoTrim-Swift.h>
@interface VideoTrim : NativeVideoTrimSpecBase <NativeVideoTrimSpec, VideoTrimProtocol>
@end

@implementation VideoTrim {
  VideoTrimSwift  * _Nullable videoTrim;
}

RCT_EXPORT_MODULE()

- (instancetype)init {
  if (self = [super init]) {
//    self.BEFORE_TRIM_PREFIX = @"beforeTrim";
  }
  return self;
}

// MARK: swift static methods
- (void)cleanFiles:(nonnull RCTPromiseResolveBlock)resolve
            reject:(nonnull RCTPromiseRejectBlock)reject {
  NSInteger successCount = [VideoTrimSwift cleanFiles];
  resolve(@(successCount));
}

- (void)deleteFile:(nonnull NSString *)filePath
           resolve:(nonnull RCTPromiseResolveBlock)resolve
            reject:(nonnull RCTPromiseRejectBlock)reject {
  resolve(@([VideoTrimSwift deleteFile:filePath]));
}

- (void)isValidFile:(nonnull NSString *)url
            resolve:(nonnull RCTPromiseResolveBlock)resolve
             reject:(nonnull RCTPromiseRejectBlock)reject {
  [VideoTrimSwift isValidFile:url url:^(NSDictionary<NSString *,id> * _Nonnull result) {
    resolve(result);
  }];
}

- (void)listFiles:(nonnull RCTPromiseResolveBlock)resolve
           reject:(nonnull RCTPromiseRejectBlock)reject {
  
  resolve([VideoTrimSwift listFiles]);
}

- (void)trim:(nonnull NSString *)url
     options:(JS::NativeVideoTrim::TrimOptions &)options
     resolve:(nonnull RCTPromiseResolveBlock)resolve
      reject:(nonnull RCTPromiseRejectBlock)reject {
  if (!self->videoTrim) {
    self->videoTrim = [[VideoTrimSwift alloc] init];
    self->videoTrim.isNewArch = true;
  }
  
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  
  dict[@"saveToPhoto"] = @(options.saveToPhoto());
  dict[@"type"] = options.type();
  dict[@"outputExt"] = options.outputExt();
  dict[@"openDocumentsOnFinish"] = @(options.openDocumentsOnFinish());
  dict[@"openShareSheetOnFinish"] = @(options.openShareSheetOnFinish());
  dict[@"removeAfterSavedToPhoto"] = @(options.removeAfterSavedToPhoto());
  dict[@"removeAfterFailedToSavePhoto"] = @(options.removeAfterFailedToSavePhoto());
  dict[@"removeAfterSavedToDocuments"] = @(options.removeAfterSavedToDocuments());
  dict[@"removeAfterFailedToSaveDocuments"] = @(options.removeAfterFailedToSaveDocuments());
  dict[@"removeAfterShared"] = @(options.removeAfterShared());
  dict[@"removeAfterFailedToShare"] = @(options.removeAfterFailedToShare());
  dict[@"enableRotation"] = @(options.enableRotation());
  dict[@"rotationAngle"] = @(options.rotationAngle());
  dict[@"startTime"] = @(options.startTime());
  dict[@"endTime"] = @(options.endTime());
  
  [self->videoTrim trim:url url:dict config:^(NSDictionary<NSString *,id> * _Nullable result) {
    if (!result) {
      reject(@"ERR_TRIM_FAILED", @"Trim failed", nil);
    } else {
      resolve(result);
    }
  }];
}

// MARK: swift instance methods
- (void)showEditor:(nonnull NSString *)filePath
            config:(JS::NativeVideoTrim::EditorConfig &)config {
  if (!self->videoTrim) {
    self->videoTrim = [[VideoTrimSwift alloc] init];
    self->videoTrim.delegate = self;
    self->videoTrim.isNewArch = true;
  }
  
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  
  dict[@"saveToPhoto"] = @(config.saveToPhoto());
  dict[@"type"] = config.type();
  dict[@"outputExt"] = config.outputExt();
  dict[@"openDocumentsOnFinish"] = @(config.openDocumentsOnFinish());
  dict[@"openShareSheetOnFinish"] = @(config.openShareSheetOnFinish());
  dict[@"removeAfterSavedToPhoto"] = @(config.removeAfterSavedToPhoto());
  dict[@"removeAfterFailedToSavePhoto"] = @(config.removeAfterFailedToSavePhoto());
  dict[@"removeAfterSavedToDocuments"] = @(config.removeAfterSavedToDocuments());
  dict[@"removeAfterFailedToSaveDocuments"] = @(config.removeAfterFailedToSaveDocuments());
  dict[@"removeAfterShared"] = @(config.removeAfterShared());
  dict[@"removeAfterFailedToShare"] = @(config.removeAfterFailedToShare());
  dict[@"enableRotation"] = @(config.enableRotation());
  dict[@"rotationAngle"] = @(config.rotationAngle());
  dict[@"enableHapticFeedback"] = @(config.enableHapticFeedback());
  dict[@"maxDuration"] = @(config.maxDuration());
  dict[@"minDuration"] = @(config.minDuration());
  dict[@"cancelButtonText"] = config.cancelButtonText();
  dict[@"saveButtonText"] = config.saveButtonText();
  dict[@"enableCancelDialog"] = @(config.enableCancelDialog());
  dict[@"cancelDialogTitle"] = config.cancelDialogTitle();
  dict[@"cancelDialogMessage"] = config.cancelDialogMessage();
  dict[@"cancelDialogCancelText"] = config.cancelDialogCancelText();
  dict[@"cancelDialogConfirmText"] = config.cancelDialogConfirmText();
  dict[@"enableSaveDialog"] = @(config.enableSaveDialog());
  dict[@"saveDialogTitle"] = config.saveDialogTitle();
  dict[@"saveDialogMessage"] = config.saveDialogMessage();
  dict[@"saveDialogCancelText"] = config.saveDialogCancelText();
  dict[@"saveDialogConfirmText"] = config.saveDialogConfirmText();
  dict[@"trimmingText"] = config.trimmingText();
  dict[@"fullScreenModalIOS"] = @(config.fullScreenModalIOS());
  dict[@"autoplay"] = @(config.autoplay());
  dict[@"jumpToPositionOnLoad"] = @(config.jumpToPositionOnLoad());
  dict[@"closeWhenFinish"] = @(config.closeWhenFinish());
  dict[@"enableCancelTrimming"] = @(config.enableCancelTrimming());
  dict[@"cancelTrimmingButtonText"] = config.cancelTrimmingButtonText();
  dict[@"enableCancelTrimmingDialog"] = @(config.enableCancelTrimmingDialog());
  dict[@"cancelTrimmingDialogTitle"] = config.cancelTrimmingDialogTitle();
  dict[@"cancelTrimmingDialogMessage"] = config.cancelTrimmingDialogMessage();
  dict[@"cancelTrimmingDialogCancelText"] = config.cancelTrimmingDialogCancelText();
  dict[@"cancelTrimmingDialogConfirmText"] = config.cancelTrimmingDialogConfirmText();
  dict[@"headerText"] = config.headerText();
  dict[@"headerTextSize"] = @(config.headerTextSize());
  dict[@"headerTextColor"] = @(config.headerTextColor());
  dict[@"alertOnFailToLoad"] = @(config.alertOnFailToLoad());
  dict[@"alertOnFailTitle"] = config.alertOnFailTitle();
  dict[@"alertOnFailMessage"] = config.alertOnFailMessage();
  dict[@"alertOnFailCloseText"] = config.alertOnFailCloseText();
  
  [self->videoTrim showEditor:filePath withConfig:dict];
}

- (void)closeEditor {
  if (self->videoTrim) {
    [self->videoTrim closeEditor:0];
  }
}

#pragma mark - VideoTrimDelegate methods
- (void)emitEventToJSWithEventName:(NSString * _Nonnull)eventName body:(NSDictionary<NSString *,id> * _Nullable)body {
  
  if ([eventName isEqualToString:@"onLog"]) {
    [self emitOnLog:body];
  } else if ([eventName isEqualToString:@"onError"]) {
    [self emitOnError:body];
  } else if ([eventName isEqualToString:@"onLoad"]) {
    [self emitOnLoad:body];
  } else if ([eventName isEqualToString:@"onStartTrimming"]) {
    [self emitOnStartTrimming];
  } else if ([eventName isEqualToString:@"onCancelTrimming"]) {
    [self emitOnCancelTrimming];
  } else if ([eventName isEqualToString:@"onCancel"]) {
    [self emitOnCancel];
  } else if ([eventName isEqualToString:@"onHide"]) {
    [self emitOnHide];
  } else if ([eventName isEqualToString:@"onShow"]) {
    [self emitOnShow];
  } else if ([eventName isEqualToString:@"onFinishTrimming"]) {
    [self emitOnFinishTrimming:body];
  } else if ([eventName isEqualToString:@"onStatistics"]) {
    [self emitOnStatistics:body];
  }
}

#pragma mark - TurboModule

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
(const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeVideoTrimSpecJSI>(params);
}

@end

#else

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_REMAP_MODULE(VideoTrim, VideoTrimSwift, RCTEventEmitter)

RCT_EXTERN_METHOD(showEditor:(NSString*)uri withConfig:(NSDictionary *)config)
RCT_EXTERN_METHOD(listFiles:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(cleanFiles:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(deleteFile:(NSString*)uri withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(closeEditor)
RCT_EXTERN_METHOD(isValidFile:(NSString*)uri withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(trim:(NSString*)uri withConfig:(NSDictionary *)config
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
@end

#endif

