//
//  AssetLoader.swift
//  react-native-video-trim
//
//  Created by Duc Trung Mai on 7/27/24.
//

import AVFoundation

protocol AssetLoaderDelegate: AnyObject {
    func assetLoader(_ loader: AssetLoader, didFailWithError error: Error, forKey key: String)
    func assetLoaderDidSucceed(_ loader: AssetLoader)
}

class AssetLoader: NSObject {
    var asset: AVURLAsset?
    weak var delegate: AssetLoaderDelegate?
    
    func loadAsset(url: URL, isVideoType: Bool) {
        // Creating AVURLAsset (not blocking the main thread)
        asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let keys = ["duration", "tracks"]
        
        // Asynchronous property loading
        asset?.loadValuesAsynchronously(forKeys: keys) {
            DispatchQueue.main.async {
                self.assetLoaded(isVideoType: isVideoType)
            }
        }
    }
    
    private func assetLoaded(isVideoType: Bool) {
        guard let asset = asset else { return }
        
        let keys = ["duration", "tracks"]
        for key in keys {
            var error: NSError?
            let status = asset.statusOfValue(forKey: key, error: &error)
            
            if status == .failed {
                if let error = error {
                    delegate?.assetLoader(self, didFailWithError: error, forKey: key)
                }
                return
            } else if status == .cancelled {
                delegate?.assetLoader(self, didFailWithError: NSError(domain: "AssetLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "\(key) loading was cancelled"]), forKey: key)
                return
            } else if status != .loaded {
                delegate?.assetLoader(self, didFailWithError: NSError(domain: "AssetLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "\(key) is in an unknown state"]), forKey: key)
                return
            }
        }
        
        if isVideoType {
            // Process the tracks to load the remaining properties
            self.processAssetTracks()
        } else {
            delegate?.assetLoaderDidSucceed(self)
        }
    }
    
    private func processAssetTracks() {
        guard let asset = asset else { return }
        
        let videoTracks = asset.tracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            delegate?.assetLoader(self, didFailWithError: NSError(domain: "AssetLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video tracks found"]), forKey: "tracks")
            return
        }
        
        let trackKeys = ["naturalSize", "preferredTransform"]
        videoTrack.loadValuesAsynchronously(forKeys: trackKeys) {
            DispatchQueue.main.async {
                self.trackPropertiesLoaded(track: videoTrack)
            }
        }
    }
    
    private func trackPropertiesLoaded(track: AVAssetTrack) {
        var error: NSError?
        
        let naturalSizeStatus = track.statusOfValue(forKey: "naturalSize", error: &error)
        let preferredTransformStatus = track.statusOfValue(forKey: "preferredTransform", error: &error)
        
        if naturalSizeStatus == .loaded, preferredTransformStatus == .loaded {
            let naturalSize = track.naturalSize
            let preferredTransform = track.preferredTransform
            
            print("Natural size: \(naturalSize)")
            print("Preferred transform: \(preferredTransform)")
            delegate?.assetLoaderDidSucceed(self)
        } else {
            if let error = error {
                let failedKey = naturalSizeStatus != .loaded ? "naturalSize" : "preferredTransform"
                delegate?.assetLoader(self, didFailWithError: error, forKey: failedKey)
            }
        }
    }
}
