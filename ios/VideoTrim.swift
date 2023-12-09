import React
import Photos

@objc(VideoTrim)
class VideoTrim: RCTEventEmitter, UIVideoEditorControllerDelegate, UINavigationControllerDelegate {
    private var isShowing = false
    private var mSaveToPhoto = true
    private var mMaxDuration: Int?
    private var hasListeners = false
    private var shouldFireFinishEvent = true
    
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
                        
                        // run "during" presenting so that user sees texts update immediately
                        // putting inside "present" will briefly show old texts then changed to new one, user can clearly see this
                        // with out DispatchQueue.main.asyncAfter, topItem is still nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let topItem = editController.navigationBar.topItem {
                                if let title = config["title"] as? String, !title.isEmpty {
                                    topItem.title = title
                                }
                                
                                // when it comes to bar button customization
                                // we can't customize text of original buttons here, we can only set attrs like enabled/hidden
                                // to customize text we need to create new button
                                if let cancelBtnText = config["cancelButtonText"] as? String, !cancelBtnText.isEmpty {
                                    topItem.leftBarButtonItem = UIBarButtonItem(title: cancelBtnText, style: topItem.leftBarButtonItem?.style ?? .plain, target: topItem.leftBarButtonItem?.target, action: topItem.leftBarButtonItem?.action)
                                }
                                
                                if let saveBtnText = config["saveButtonText"] as? String, !saveBtnText.isEmpty {
                                    topItem.rightBarButtonItem = UIBarButtonItem(title: saveBtnText, style: topItem.rightBarButtonItem?.style ?? .plain, target: topItem.rightBarButtonItem?.target, action: topItem.rightBarButtonItem?.action)
                                }
                            }
                        }
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
        if (!shouldFireFinishEvent) {
            return
        }
        shouldFireFinishEvent = false
        
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
//        editor.delegate = nil
        
        // but with the above solution, somehow it'll close React Native Modal when the editor controller dismissed
        // so we have to create a flag shouldFireFinishEvent here


        editor.dismiss(animated: true, completion: {
            self.emitEventToJS("onHide", eventData: nil)
            self.isShowing = false
            self.shouldFireFinishEvent = true // reset this flag to true once dismiss
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
