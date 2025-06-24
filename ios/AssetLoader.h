#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class AssetLoader;

@protocol AssetLoaderDelegate <NSObject>
@optional
- (void)assetLoaderDidSucceed:(AssetLoader *)assetLoader;
- (void)assetLoader:(AssetLoader *)assetLoader didFailWithError:(NSError *)error forKey:(NSString *)key;
@end

@interface AssetLoader : NSObject

@property (nonatomic, weak) id<AssetLoaderDelegate> delegate;
@property (nonatomic, strong, readonly) AVURLAsset *asset;

- (void)loadAssetWithURL:(NSURL *)url isVideoType:(BOOL)isVideoType;

@end
