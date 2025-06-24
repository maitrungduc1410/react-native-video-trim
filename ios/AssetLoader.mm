#import "AssetLoader.h"

@interface AssetLoader ()
@property (nonatomic, strong) AVURLAsset *asset;
@end

@implementation AssetLoader

- (void)loadAssetWithURL:(NSURL *)url isVideoType:(BOOL)isVideoType {
    NSDictionary *options = @{ AVURLAssetPreferPreciseDurationAndTimingKey: @YES };
    self.asset = [AVURLAsset URLAssetWithURL:url options:options];
    NSArray *keys = @[ @"duration", @"tracks" ];
    [self.asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        [self assetLoaded:isVideoType];
    }];
}

- (void)assetLoaded:(BOOL)isVideoType {
    NSArray *keys = @[ @"duration", @"tracks" ];
    for (NSString *key in keys) {
        NSError *error = nil;
        AVKeyValueStatus status = [self.asset statusOfValueForKey:key error:&error];
        if (status == AVKeyValueStatusFailed) {
            if ([self.delegate respondsToSelector:@selector(assetLoader:didFailWithError:forKey:)]) {
                [self.delegate assetLoader:self didFailWithError:error forKey:key];
            }
            return;
        } else if (status == AVKeyValueStatusCancelled) {
            NSError *cancelError = [NSError errorWithDomain:@"AssetLoader" code:-1 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@ loading was cancelled", key] }];
            if ([self.delegate respondsToSelector:@selector(assetLoader:didFailWithError:forKey:)]) {
                [self.delegate assetLoader:self didFailWithError:cancelError forKey:key];
            }
            return;
        } else if (status != AVKeyValueStatusLoaded) {
            NSError *unknownError = [NSError errorWithDomain:@"AssetLoader" code:-1 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@ is in an unknown state", key] }];
            if ([self.delegate respondsToSelector:@selector(assetLoader:didFailWithError:forKey:)]) {
                [self.delegate assetLoader:self didFailWithError:unknownError forKey:key];
            }
            return;
        }
    }
    if (isVideoType) {
        [self processAssetTracks];
    } else {
        if ([self.delegate respondsToSelector:@selector(assetLoaderDidSucceed:)]) {
            [self.delegate assetLoaderDidSucceed:self];
        }
    }
}

- (void)processAssetTracks {
    NSArray *videoTracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = videoTracks.firstObject;
    if (!videoTrack) {
        NSError *error = [NSError errorWithDomain:@"AssetLoader" code:-1 userInfo:@{ NSLocalizedDescriptionKey: @"No video tracks found" }];
        if ([self.delegate respondsToSelector:@selector(assetLoader:didFailWithError:forKey:)]) {
            [self.delegate assetLoader:self didFailWithError:error forKey:@"tracks"];
        }
        return;
    }
    NSArray *trackKeys = @[ @"naturalSize", @"preferredTransform" ];
    [videoTrack loadValuesAsynchronouslyForKeys:trackKeys completionHandler:^{
        [self trackPropertiesLoaded:videoTrack];
    }];
}

- (void)trackPropertiesLoaded:(AVAssetTrack *)track {
    NSError *error = nil;
    AVKeyValueStatus naturalSizeStatus = [track statusOfValueForKey:@"naturalSize" error:&error];
    AVKeyValueStatus preferredTransformStatus = [track statusOfValueForKey:@"preferredTransform" error:&error];
    if (naturalSizeStatus == AVKeyValueStatusLoaded && preferredTransformStatus == AVKeyValueStatusLoaded) {
        CGSize naturalSize = track.naturalSize;
        CGAffineTransform preferredTransform = track.preferredTransform;
        NSLog(@"Natural size: %@", NSStringFromCGSize(naturalSize));
        NSLog(@"Preferred transform: %@", NSStringFromCGAffineTransform(preferredTransform));
        if ([self.delegate respondsToSelector:@selector(assetLoaderDidSucceed:)]) {
            [self.delegate assetLoaderDidSucceed:self];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(assetLoader:didFailWithError:forKey:)]) {
            NSString *failedKey = (naturalSizeStatus != AVKeyValueStatusLoaded) ? @"naturalSize" : @"preferredTransform";
            [self.delegate assetLoader:self didFailWithError:error forKey:failedKey];
        }
    }
}

@end
