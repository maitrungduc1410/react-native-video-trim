#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(VideoTrim, RCTEventEmitter)

RCT_EXTERN_METHOD(showEditor:(NSString*)uri withConfig:(NSDictionary *)config)
RCT_EXTERN_METHOD(isValidVideo:(NSString*)uri withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

@end
