import React
import Photos

@objc(VideoTrim)
class VideoTrim: RCTEventEmitter, UIVideoEditorControllerDelegate, UINavigationControllerDelegate {
    private var isShowing = false
    private var mSaveToPhoto = true
    private var mMaxDuration: Int?
    private var hasListeners = false
    
    @objc
    static override func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    override func supportedEvents() -> [String]! {
        return ["VideoTrim"]
    }
    
    override func startObserving() {
        hasListeners = true
    }
    
    override func stopObserving() {
        hasListeners = false
    }
    
    @objc(isValidVideo:withResolver:withRejecter:)
    func isValidVideo(uri: String, resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
        if let destPath = copyFileToDocumentDir(uri: uri) {
            resolve(UIVideoEditorController.canEditVideo(atPath: destPath))
        } else {
            resolve(false)
        }
    }
    
    @objc(showEditor:withConfig:)
    func showEditor(uri: String, config: NSDictionary){
        if isShowing {
            return
        }
        
        if let saveToPhoto = config["saveToPhoto"] as? Bool {
            self.mSaveToPhoto = saveToPhoto
        }
        
        if let maxDuration = config["maxDuration"] as? Int {
            self.mMaxDuration = maxDuration
        }
    
        if let destPath = copyFileToDocumentDir(uri: uri) {
            if UIVideoEditorController.canEditVideo(atPath: destPath) {
                DispatchQueue.main.async {
                    let editController = UIVideoEditorController()
                    editController.videoPath = destPath
                    editController.videoQuality = .typeHigh
                    
                    if (self.mMaxDuration != nil) {
                        editController.videoMaximumDuration = Double(self.mMaxDuration!)
                    }
                    
                    editController.delegate = self
                    if let root = RCTPresentedViewController() {
                        root.present(editController, animated: true, completion: {
                            self.emitEventToJS("onShow", eventData: nil)
                            self.isShowing = true
                        })
                    }
                }
            } else {
                let eventPayload: [String: Any] = ["message": "File is not a valid video"]
                self.emitEventToJS("onError", eventData: eventPayload)
            }
        } else {
            let eventPayload: [String: Any] = ["message": "File is invalid"]
            self.emitEventToJS("onError", eventData: eventPayload)
        }
    }
    
    func videoEditorController(_ editor: UIVideoEditorController,
                               didSaveEditedVideoToPath editedVideoPath: String) {
        let eventPayload: [String: Any] = ["outputPath": editedVideoPath]
        self.emitEventToJS("onFinishTrimming", eventData: eventPayload)
        
        if (mSaveToPhoto) {
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else {
                    let eventPayload: [String: Any] = ["message": "Permission to access Photo Library is not granted"]
                    self.emitEventToJS("onError", eventData: eventPayload)
                    return
                }
                
                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: editedVideoPath))
                    request?.creationDate = Date()
                }) { success, error in
                    if success {
                        print("Edited video saved to Photo Library successfully.")
                    } else {
                        let eventPayload: [String: Any] = ["message": "Failed to save edited video to Photo Library: \(error?.localizedDescription ?? "Unknown error")"]
                        self.emitEventToJS("onError", eventData: eventPayload)
                    }
                }
            }
        }
        
        // the edit has a known bug where it fires "didSaveEditedVideoToPath" twice, so we have to set its delete to nil right after first call
        editor.delegate = nil
        
        
        editor.dismiss(animated: true, completion: {
            self.emitEventToJS("onHide", eventData: nil)
            self.isShowing = false
        })
    }
    
    func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        self.emitEventToJS("onCancelTrimming", eventData: nil)
        editor.dismiss(animated: true, completion: {
            self.emitEventToJS("onHide", eventData: nil)
            self.isShowing = false
        })
    }
    
    func videoEditorController(_ editor: UIVideoEditorController,
                               didFailWithError error: Error) {
        let eventPayload: [String: Any] = ["message": error.localizedDescription]
        self.emitEventToJS("onError", eventData: eventPayload)
        editor.dismiss(animated: true, completion: {
            self.emitEventToJS("onHide", eventData: nil)
            self.isShowing = false
        })
    }

    
    private func copyFileToDocumentDir(uri: String) -> String? {
        if let videoURL = URL(string: uri) {
            // Save the video to the document directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            // Extract the file extension from the videoURL
            let fileExtension = videoURL.pathExtension
            
            // Define the filename with the correct file extension
            let destinationURL = documentsDirectory.appendingPathComponent("editedVideo.\(fileExtension)")
            
            do {
                // Remove the old file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.copyItem(at: videoURL, to: destinationURL)
            } catch {
                return nil
            }
            
            return destinationURL.path
        } else {
            return nil
        }
    }
    
    private func emitEventToJS(_ eventName: String, eventData: [String: Any]?) {
        if hasListeners {
            var modifiedEventData = eventData ?? [:] // If eventData is nil, create an empty dictionary
            modifiedEventData["name"] = eventName
            sendEvent(withName: "VideoTrim", body: modifiedEventData)
        }
    }
}
