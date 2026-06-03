// because Swift class inherits from RCTEventEmitter, hence we need to import it here for both new and old arch
#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED

#import <VideoTrimSpec/VideoTrimSpec.h>

#if __has_include(<VideoTrim/VideoTrim-Swift.h>)
// if use_frameworks! :static
#import <VideoTrim/VideoTrim-Swift.h>
#else
#import "VideoTrim-Swift.h"
#endif

@interface VideoTrim : NativeVideoTrimSpecBase <NativeVideoTrimSpec, VideoTrimProtocol>
@end

@implementation VideoTrim {
  VideoTrimSwift  * _Nullable videoTrim;
}

RCT_EXPORT_MODULE()

- (instancetype)init {
  if (self = [super init]) {
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
  dict[@"removeAfterSavedToPhoto"] = @(options.removeAfterSavedToPhoto());
  dict[@"removeAfterFailedToSavePhoto"] = @(options.removeAfterFailedToSavePhoto());
  dict[@"startTime"] = @(options.startTime());
  dict[@"endTime"] = @(options.endTime());
  dict[@"enablePreciseTrimming"] = @(options.enablePreciseTrimming());
  dict[@"removeAudio"] = @(options.removeAudio());
  dict[@"speed"] = @(options.speed());
  
  [self->videoTrim trimWithInputFile:url config:dict completion:^(NSDictionary<NSString *,id> * _Nonnull result) {
    BOOL success = [result[@"success"] boolValue];
    if (success) {
      resolve(result);
    } else {
      NSString *message = result[@"message"];
      NSError *error = [NSError errorWithDomain:@"" code:200 userInfo:nil];
      reject(@"ERR_TRIM_FAILED", message, error);
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
  dict[@"enableHapticFeedback"] = @(config.enableHapticFeedback());
  dict[@"enableEditTools"] = @(config.enableEditTools());
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
  dict[@"enablePreciseTrimming"] = @(config.enablePreciseTrimming());
  dict[@"removeAudio"] = @(config.removeAudio());
  dict[@"speed"] = @(config.speed());
  
  // Handle optional color values
  auto trimmerColorOpt = config.trimmerColor();
  if (trimmerColorOpt.has_value()) {
    dict[@"trimmerColor"] = @(trimmerColorOpt.value());
  }
  
  auto handleIconColorOpt = config.handleIconColor();
  if (handleIconColorOpt.has_value()) {
    dict[@"handleIconColor"] = @(handleIconColorOpt.value());
  }
  
  auto waveformColorOpt = config.waveformColor();
  if (waveformColorOpt.has_value()) {
    dict[@"waveformColor"] = @(waveformColorOpt.value());
  }
  
  auto waveformBackgroundColorOpt = config.waveformBackgroundColor();
  if (waveformBackgroundColorOpt.has_value()) {
    dict[@"waveformBackgroundColor"] = @(waveformBackgroundColorOpt.value());
  }
  
  auto waveformBarWidthOpt = config.waveformBarWidth();
  if (waveformBarWidthOpt.has_value()) {
    dict[@"waveformBarWidth"] = @(waveformBarWidthOpt.value());
  }
  
  auto waveformBarGapOpt = config.waveformBarGap();
  if (waveformBarGapOpt.has_value()) {
    dict[@"waveformBarGap"] = @(waveformBarGapOpt.value());
  }
  
  auto waveformBarCornerRadiusOpt = config.waveformBarCornerRadius();
  if (waveformBarCornerRadiusOpt.has_value()) {
    dict[@"waveformBarCornerRadius"] = @(waveformBarCornerRadiusOpt.value());
  }
  
  auto zoomOnWaitingDurationOpt = config.zoomOnWaitingDuration();
  if (zoomOnWaitingDurationOpt.has_value()) {
    dict[@"zoomOnWaitingDuration"] = @(zoomOnWaitingDurationOpt.value());
  }
  
  NSString *theme = config.theme();
  if (theme != nil) {
    dict[@"theme"] = theme;
  }
  
  NSString *durationFormat = config.durationFormat();
  if (durationFormat != nil) {
    dict[@"durationFormat"] = durationFormat;
  }
  
  [self->videoTrim showEditor:filePath withConfig:dict];
}

- (void)getFrameAt:(nonnull NSString *)url
           options:(JS::NativeVideoTrim::FrameExtractionOptions &)options
           resolve:(nonnull RCTPromiseResolveBlock)resolve
            reject:(nonnull RCTPromiseRejectBlock)reject {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[@"time"] = @(options.time());
  dict[@"format"] = options.format();
  dict[@"quality"] = @(options.quality());
  dict[@"maxWidth"] = @(options.maxWidth());
  dict[@"maxHeight"] = @(options.maxHeight());

  [VideoTrimSwift getFrameAt:url options:dict completion:^(NSDictionary<NSString *, id> * _Nonnull result) {
    if (result[@"error"]) {
      reject(@"ERR_FRAME_EXTRACTION", result[@"error"], [NSError errorWithDomain:@"" code:200 userInfo:nil]);
    } else {
      resolve(result);
    }
  }];
}

- (void)extractAudio:(nonnull NSString *)url
             options:(JS::NativeVideoTrim::ExtractAudioOptions &)options
             resolve:(nonnull RCTPromiseResolveBlock)resolve
              reject:(nonnull RCTPromiseRejectBlock)reject {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[@"outputExt"] = options.outputExt();

  [VideoTrimSwift extractAudio:url options:dict completion:^(NSDictionary<NSString *, id> * _Nonnull result) {
    if (result[@"error"]) {
      reject(@"ERR_EXTRACT_AUDIO", result[@"error"], [NSError errorWithDomain:@"" code:200 userInfo:nil]);
    } else {
      resolve(result);
    }
  }];
}

- (void)compress:(nonnull NSString *)url
         options:(JS::NativeVideoTrim::CompressOptions &)options
         resolve:(nonnull RCTPromiseResolveBlock)resolve
          reject:(nonnull RCTPromiseRejectBlock)reject {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[@"quality"] = options.quality();
  dict[@"bitrate"] = @(options.bitrate());
  dict[@"width"] = @(options.width());
  dict[@"height"] = @(options.height());
  dict[@"frameRate"] = @(options.frameRate());
  dict[@"outputExt"] = options.outputExt();
  dict[@"removeAudio"] = @(options.removeAudio());

  [VideoTrimSwift compress:url options:dict completion:^(NSDictionary<NSString *, id> * _Nonnull result) {
    if (result[@"error"]) {
      reject(@"ERR_COMPRESS", result[@"error"], [NSError errorWithDomain:@"" code:200 userInfo:nil]);
    } else {
      resolve(result);
    }
  }];
}

- (void)toGif:(nonnull NSString *)url
      options:(JS::NativeVideoTrim::GifOptions &)options
      resolve:(nonnull RCTPromiseResolveBlock)resolve
       reject:(nonnull RCTPromiseRejectBlock)reject {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[@"startTime"] = @(options.startTime());
  dict[@"endTime"] = @(options.endTime());
  dict[@"fps"] = @(options.fps());
  dict[@"width"] = @(options.width());

  [VideoTrimSwift toGif:url options:dict completion:^(NSDictionary<NSString *, id> * _Nonnull result) {
    if (result[@"error"]) {
      reject(@"ERR_GIF", result[@"error"], [NSError errorWithDomain:@"" code:200 userInfo:nil]);
    } else {
      resolve(result);
    }
  }];
}

- (void)merge:(nonnull NSArray<NSString *> *)urls
      options:(JS::NativeVideoTrim::MergeOptions &)options
      resolve:(nonnull RCTPromiseResolveBlock)resolve
       reject:(nonnull RCTPromiseRejectBlock)reject {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[@"outputExt"] = options.outputExt();

  [VideoTrimSwift merge:urls options:dict completion:^(NSDictionary<NSString *, id> * _Nonnull result) {
    if (result[@"error"]) {
      reject(@"ERR_MERGE", result[@"error"], [NSError errorWithDomain:@"" code:200 userInfo:nil]);
    } else {
      resolve(result);
    }
  }];
}

- (void)saveToPhoto:(nonnull NSString *)filePath
            resolve:(nonnull RCTPromiseResolveBlock)resolve
             reject:(nonnull RCTPromiseRejectBlock)reject {
  [VideoTrimSwift saveToPhoto:filePath completion:^(NSDictionary<NSString *, id> * _Nonnull result) {
    if (result[@"error"]) {
      reject(@"ERR_SAVE_TO_PHOTO", result[@"error"], [NSError errorWithDomain:@"" code:200 userInfo:nil]);
    } else {
      resolve(result);
    }
  }];
}

- (void)saveToDocuments:(nonnull NSString *)filePath
                resolve:(nonnull RCTPromiseResolveBlock)resolve
                 reject:(nonnull RCTPromiseRejectBlock)reject {
  [VideoTrimSwift saveToDocuments:filePath completion:^(NSDictionary<NSString *, id> * _Nonnull result) {
    if (result[@"error"]) {
      reject(@"ERR_SAVE_TO_DOCUMENTS", result[@"error"], [NSError errorWithDomain:@"" code:200 userInfo:nil]);
    } else {
      resolve(result);
    }
  }];
}

- (void)share:(nonnull NSString *)filePath
      resolve:(nonnull RCTPromiseResolveBlock)resolve
       reject:(nonnull RCTPromiseRejectBlock)reject {
  [VideoTrimSwift share:filePath completion:^(NSDictionary<NSString *, id> * _Nonnull result) {
    if (result[@"error"]) {
      reject(@"ERR_SHARE", result[@"error"], [NSError errorWithDomain:@"" code:200 userInfo:nil]);
    } else {
      resolve(result);
    }
  }];
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
RCT_EXTERN_METHOD(getFrameAt:(NSString*)url withOptions:(NSDictionary *)options
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(extractAudio:(NSString*)url withOptions:(NSDictionary *)options
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(compress:(NSString*)url withOptions:(NSDictionary *)options
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(toGif:(NSString*)url withOptions:(NSDictionary *)options
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(merge:(NSArray *)urls withOptions:(NSDictionary *)options
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(saveToPhoto:(NSString*)filePath withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(saveToDocuments:(NSString*)filePath withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(share:(NSString*)filePath withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
@end

#endif
