import React
import Photos
import ffmpegkit

@available(iOS 13.0, *)
@objc(VideoTrim)
class VideoTrim: RCTEventEmitter, AssetLoaderDelegate, UIDocumentPickerDelegate {
    private let FILE_PREFIX = "trimmedVideo"
    private var hasListeners = false
    private var isShowing = false
    
    private var saveToPhoto = false
    private var removeAfterSavedToPhoto = false
    private var removeAfterFailedToSavePhoto = false
    private var removeAfterSavedToDocuments = false
    private var removeAfterFailedToSaveDocuments = false
    private var removeAfterShared = false
    private var removeAfterFailedToShare = false
    
    private var trimmingText = "Trimming video..."
    private var enableCancelDialog = true
    private var cancelDialogTitle = "Warning!"
    private var cancelDialogMessage = "Are you sure want to cancel?"
    private var cancelDialogCancelText = "Close"
    private var cancelDialogConfirmText = "Proceed"
    private var enableSaveDialog = true
    private var saveDialogTitle = "Confirmation!"
    private var saveDialogMessage = "Are you sure want to save?"
    private var saveDialogCancelText = "Close"
    private var saveDialogConfirmText = "Proceed"
    private var fullScreenModalIOS  = false
    private var maxDuration: Int?
    private var minDuration: Int?
    private var cancelButtonText = "Cancel"
    private var saveButtonText = "Save"
    private var vc: VideoTrimmerViewController?
    private var isVideoType = true
    private var outputExt = "mp4"
    private var openDocumentsOnFinish = false
    private var openShareSheetOnFinish = false
    private var outputFile: URL?
    private var enableHapticFeedback = true

    
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
    
    @objc(showEditor:withConfig:)
    func showEditor(uri: String, config: NSDictionary){
        if isShowing {
            return
        }
        saveToPhoto = config["saveToPhoto"] as? Bool ?? false
        
        removeAfterSavedToPhoto = config["removeAfterSavedToPhoto"] as? Bool ?? false
        removeAfterFailedToSavePhoto = config["removeAfterFailedToSavePhoto"] as? Bool ?? false
        removeAfterSavedToDocuments = config["removeAfterSavedToDocuments"] as? Bool ?? false
        removeAfterFailedToSaveDocuments = config["removeAfterFailedToSaveDocuments"] as? Bool ?? false
        removeAfterShared = config["removeAfterShared"] as? Bool ?? false
        removeAfterFailedToShare = config["removeAfterFailedToShare"] as? Bool ?? false
        
        enableCancelDialog = config["enableCancelDialog"] as? Bool ?? true
        cancelDialogTitle = config["cancelDialogTitle"] as? String ?? "Warning!"
        cancelDialogMessage = config["cancelDialogMessage"] as? String ?? "Are you sure want to cancel?"
        cancelDialogCancelText = config["cancelDialogCancelText"] as? String ?? "Close"
        cancelDialogConfirmText = config["cancelDialogConfirmText"] as? String ?? "Proceed"
        
        enableSaveDialog = config["enableSaveDialog"] as? Bool ?? true
        saveDialogTitle = config["saveDialogTitle"] as? String ?? "Confirmation!"
        saveDialogMessage = config["saveDialogMessage"] as? String ?? "Are you sure want to save?"
        saveDialogCancelText = config["saveDialogCancelText"] as? String ?? "Close"
        saveDialogConfirmText = config["saveDialogConfirmText"] as? String ?? "Proceed"
        trimmingText = config["trimmingText"] as? String ?? "Trimming video..."
        fullScreenModalIOS = config["fullScreenModalIOS"] as? Bool ?? false
        isVideoType = (config["type"] as? String ?? "video") == "video"
        outputExt = config["outputExt"] as? String ?? "mp4"
        openDocumentsOnFinish = config["openDocumentsOnFinish"] as? Bool ?? false
        openShareSheetOnFinish = config["openShareSheetOnFinish"] as? Bool ?? false
        enableHapticFeedback = config["enableHapticFeedback"] as? Bool ?? true

        if let maxDuration = config["maxDuration"] as? Int {
            self.maxDuration = maxDuration
        }
        
        if let minDuration = config["minDuration"] as? Int {
            self.minDuration = minDuration
        }
        
        if let cancelBtnText = config["cancelButtonText"] as? String, !cancelBtnText.isEmpty {
            self.cancelButtonText = cancelBtnText
        }
        
        if let saveButtonText = config["saveButtonText"] as? String, !saveButtonText.isEmpty {
            self.saveButtonText = saveButtonText
        }
        
        let destPath = URL(string: uri)
        guard let destPath = destPath else { return }
        let assetLoader = AssetLoader()
        assetLoader.delegate = self
        assetLoader.loadAsset(url: destPath, isVideoType: isVideoType)
        
        DispatchQueue.main.async {
            self.vc = VideoTrimmerViewController()
            
            guard let vc = self.vc else { return }
            
            vc.maximumDuration = self.maxDuration
            vc.minimumDuration = self.minDuration
            vc.cancelBtnText = self.cancelButtonText
            vc.saveButtonText = self.saveButtonText
            vc.isVideoType = self.isVideoType
            vc.enableHapticFeedback = self.enableHapticFeedback

            
            vc.cancelBtnClicked = {
                if !self.enableCancelDialog {
                    self.emitEventToJS("onCancelTrimming", eventData: nil)
                    
                    vc.dismiss(animated: true, completion: {
                        self.emitEventToJS("onHide", eventData: nil)
                        self.isShowing = false
                    })
                    return
                }
                
                // Create Alert
                let dialogMessage = UIAlertController(title: self.cancelDialogTitle, message: self.cancelDialogMessage, preferredStyle: .alert)
                
                // Create OK button with action handler
                let ok = UIAlertAction(title: self.cancelDialogConfirmText, style: .destructive, handler: { (action) -> Void in
                    self.emitEventToJS("onCancelTrimming", eventData: nil)
                    
                    vc.dismiss(animated: true, completion: {
                        self.emitEventToJS("onHide", eventData: nil)
                        self.isShowing = false
                    })
                })
                
                // Create Cancel button with action handlder
                let cancel = UIAlertAction(title: self.cancelDialogCancelText, style: .cancel)
                
                //Add OK and Cancel button to an Alert object
                dialogMessage.addAction(ok)
                dialogMessage.addAction(cancel)
                
                // Present alert message to user
                if let root = RCTPresentedViewController() {
                    root.present(dialogMessage, animated: true, completion: nil)
                }
            }
            
            vc.saveBtnClicked = {(selectedRange: CMTimeRange) in
                if !self.enableSaveDialog {
                    self.trim(viewController: vc,inputFile: destPath, videoDuration: self.vc!.asset!.duration.seconds, startTime: selectedRange.start.seconds, endTime: selectedRange.end.seconds)
                    return
                }
                
                // Create Alert
                let dialogMessage = UIAlertController(title: self.saveDialogTitle, message: self.saveDialogMessage, preferredStyle: .alert)
                
                // Create OK button with action handler
                let ok = UIAlertAction(title: self.saveDialogConfirmText, style: .default, handler: { (action) -> Void in
                    self.trim(viewController: vc,inputFile: destPath, videoDuration: vc.asset!.duration.seconds, startTime: selectedRange.start.seconds, endTime: selectedRange.end.seconds)
                })
                
                // Create Cancel button with action handlder
                let cancel = UIAlertAction(title: self.saveDialogCancelText, style: .cancel)
                
                //Add OK and Cancel button to an Alert object
                dialogMessage.addAction(ok)
                dialogMessage.addAction(cancel)
                
                // Present alert message to user
                if let root = RCTPresentedViewController() {
                    root.present(dialogMessage, animated: true, completion: nil)
                }
            }
            
            vc.isModalInPresentation = true // prevent modal closed by swipe down
            
            if self.fullScreenModalIOS {
                vc.modalPresentationStyle = .fullScreen
            }
            
            if let root = RCTPresentedViewController() {
                root.present(vc, animated: true, completion: {
                    self.emitEventToJS("onShow", eventData: nil)
                    self.isShowing = true
                })
            }
        }
        
    }
    
    private func copyFileToDocumentDir(uri: String) -> URL? {
        if let videoURL = URL(string: uri) {
            // Save the video to the document directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            // Extract the file extension from the videoURL
            let fileExtension = videoURL.pathExtension
            
            // Define the filename with the correct file extension
            let timestamp = Int(Date().timeIntervalSince1970)
            let destinationURL = documentsDirectory.appendingPathComponent("\(FILE_PREFIX)_original_\(timestamp).\(fileExtension)")
            
            do {
                try FileManager.default.copyItem(at: videoURL, to: destinationURL)
            } catch {
                print("Error while copying file to document directory \(error)")
                return nil
            }
            
            return destinationURL
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
    
    @objc(listFiles:withRejecter:)
    func listFiles(resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
        let files = listFiles()
        resolve(files.map{ $0.absoluteString })
    }
    
    @objc(cleanFiles:withRejecter:)
    func cleanFiles(resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
        let files = listFiles()
        var successCount = 0
        for file in files {
            let state = deleteFile(url: file)
            
            if state == 0 {
                successCount += 1
            }
        }
        
        resolve(successCount)
    }
    
    @objc(deleteFile:withResolver:withRejecter:)
    func deleteFile(uri: String, resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
        let state = deleteFile(url: URL(string: uri)!)
        resolve(state == 0)
    }
    
    private func listFiles() -> [URL] {
        var files: [URL] = []
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in directoryContents {
                if fileURL.lastPathComponent.starts(with: FILE_PREFIX) {
                    files.append(fileURL)
                }
            }
        } catch {
            print("[listFiles] Error when retrieving files: \(error)")
        }
        
        return files
    }
    
    private func deleteFile(url: URL) -> Int {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                
                return 0
            }
            
            return 1
        } catch {
            print("[deleteFile] Error deleting files: \(error)")
            
            return 2
        }
    }
    
    private func trim(viewController: VideoTrimmerViewController, inputFile: URL, videoDuration: Double, startTime: Double, endTime: Double) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let outputName = "\(FILE_PREFIX)_\(timestamp).\(outputExt)"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        outputFile = documentsDirectory.appendingPathComponent(outputName)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateTime = formatter.string(from: Date())
        
        self.emitEventToJS("onStartTrimming", eventData: nil)
        
        // Create Alert
        let progressDialog = UIAlertController(title: trimmingText, message: nil, preferredStyle: .alert)
        
        // Present alert message to user
        let progressView = UIProgressView(frame: .zero)
        progressView.tintColor = .systemBlue
        if let root = RCTPresentedViewController() {
            root.present(progressDialog, animated: true, completion: {
                progressDialog.view.addSubview(progressView)
                
                progressView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    progressView.leadingAnchor.constraint(equalTo: progressDialog.view.leadingAnchor, constant: 8),
                    progressView.trailingAnchor.constraint(equalTo: progressDialog.view.trailingAnchor, constant: -8),
                    progressView.bottomAnchor.constraint(equalTo: progressDialog.view.bottomAnchor, constant: -8)
                ])
            })
        }
        
        let cmds = [
            "-ss",
            "\(startTime * 1000)ms",
            "-to",
            "\(endTime * 1000)ms",
            "-i",
            "\(inputFile)",
            "-c",
            "copy",
            "-metadata",
            "creation_time=\(dateTime)",
            outputFile!.absoluteString
        ]
        
        print("Command: ", cmds.joined(separator: " "))
        
        let eventPayload: [String: Any] = [
            "command": cmds.joined(separator: " ")
        ]
        self.emitEventToJS("onLog", eventData: eventPayload)
        
        FFmpegKit.execute(withArgumentsAsync: cmds, withCompleteCallback: { session in
            DispatchQueue.main.async {
                progressDialog.dismiss(animated: true)
            }
            
            let state = session?.getState()
            let returnCode = session?.getReturnCode()

            if ReturnCode.isSuccess(returnCode) {
                let eventPayload: [String: Any] = ["outputPath": self.outputFile!.absoluteString, "startTime": (startTime * 1000).rounded(), "endTime": (endTime * 1000).rounded(), "duration": (videoDuration * 1000).rounded()]
                self.emitEventToJS("onFinishTrimming", eventData: eventPayload)
                
                if (self.saveToPhoto && self.isVideoType) {
                    PHPhotoLibrary.requestAuthorization { status in
                        guard status == .authorized else {
                            self.onError(message: "Permission to access Photo Library is not granted", code: .noPhotoPermission)
                            return
                        }
                        
                        PHPhotoLibrary.shared().performChanges({
                            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.outputFile!)
                            request?.creationDate = Date()
                        }) { success, error in
                            if success {
                                print("Edited video saved to Photo Library successfully.")
                                
                                if self.removeAfterSavedToPhoto {
                                    let _ = self.deleteFile(url: self.outputFile!)
                                }
                            } else {
                                self.onError(message: "Failed to save edited video to Photo Library: \(error?.localizedDescription ?? "Unknown error")", code: .failToSaveToPhoto)
                                if self.removeAfterFailedToSavePhoto {
                                    let _ = self.deleteFile(url: self.outputFile!)
                                }
                            }
                        }
                    }
                } else if self.openDocumentsOnFinish {
                    self.saveFileToFilesApp(fileURL: self.outputFile!)
                    
                    // must return otherwise editor will close
                    return
                } else if self.openShareSheetOnFinish {
                    self.shareFile(fileURL: self.outputFile!)
                    
                    // must return otherwise editor will close
                    return
                }
            } else {
                // CANCEL + FAILURE
                self.onError(message: "Command failed with state \(String(describing: FFmpegKitConfig.sessionState(toString: state ?? .failed))) and rc \(String(describing: returnCode)).\(String(describing: session?.getFailStackTrace()))", code: .trimmingFailed)
            }
            
            self.closeEditor()
        }, withLogCallback: { log in
            guard let log = log else { return }
            
            print("FFmpeg process started with log " + (log.getMessage()));
            
            let eventPayload: [String: Any] = [
                "level": log.getLevel(),
                "message": log.getMessage() ?? "",
                "sessionId": log.getSessionId(),
            ]
            self.emitEventToJS("onLog", eventData: eventPayload)
            
        }, withStatisticsCallback: { statistics in
            guard let statistics = statistics else { return }
            
            let timeInMilliseconds = statistics.getTime()
            if timeInMilliseconds > 0 {
                let completePercentage = timeInMilliseconds / (videoDuration * 1000); // from 0 -> 1
                DispatchQueue.main.async {
                    progressView.setProgress(Float(completePercentage), animated: true)
                }
            }
            
            let eventPayload: [String: Any] = [
                "sessionId": statistics.getSessionId(),
                "videoFrameNumber": statistics.getVideoFrameNumber(),
                "videoFps": statistics.getVideoFps(),
                "videoQuality": statistics.getVideoQuality(),
                "size": statistics.getSize(),
                "time": statistics.getTime(),
                "bitrate": statistics.getBitrate(),
                "speed": statistics.getSpeed()
            ]
            self.emitEventToJS("onStatistics", eventData: eventPayload)
        })
    }
    
    func assetLoader(_ loader: AssetLoader, didFailWithError error: any Error, forKey key: String) {
        let message = "Failed to load \(key): \(error.localizedDescription)"
        print(message)
        
        self.onError(message: message, code: .failToLoadVideo)
        vc?.onAssetFailToLoad()
    }
    
    func assetLoaderDidSucceed(_ loader: AssetLoader) {
        print("Asset loaded successfully")
        
        vc?.asset = loader.asset
    }
    
    
    
    private func saveFileToFilesApp(fileURL: URL) {
        DispatchQueue.main.async {
            let documentPicker = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = .formSheet
            if let root = RCTPresentedViewController() {
                root.present(documentPicker, animated: true, completion: nil)
            }
        }
    }
    
    private func shareFile(fileURL: URL) {
        DispatchQueue.main.async {
            // Create an instance of UIActivityViewController
            let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                
                if let error = error {
                    let message = "Sharing error: \(error.localizedDescription)"
                    print(message)
                    self.onError(message: message, code: .failToShare)
                    
                    if self.removeAfterFailedToShare {
                        let _ = self.deleteFile(url: self.outputFile!)
                    }
                    return
                }
                
                if completed {
                    print("User completed the sharing activity")
                    if self.removeAfterShared {
                        let _ = self.deleteFile(url: self.outputFile!)
                    }
                } else {
                    print("User cancelled or failed to complete the sharing activity")
                    if self.removeAfterFailedToShare {
                        let _ = self.deleteFile(url: self.outputFile!)
                    }
                }
                
                self.closeEditor()

            }
            
            // Present the share sheet
            if let root = RCTPresentedViewController() {
                root.present(activityViewController, animated: true, completion: nil)
            }
        }
        
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if removeAfterSavedToDocuments {
            let _ = deleteFile(url: outputFile!)
        }
        closeEditor()
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        if removeAfterFailedToSaveDocuments {
            let _ = deleteFile(url: outputFile!)
        }
        closeEditor()
    }
    
    @objc(closeEditor:withRejecter:)
    func closeEditor(resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
        closeEditor()
        resolve(true)
    }
    
    private func closeEditor() {
        guard let vc = vc else { return }
        // some how in case we trim a very short video the view controller is still visible after first .dismiss call
        // even the file is successfully saved
        // that's why we need a small delay here to ensure vc will be dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            vc.dismiss(animated: true, completion: {
                self.emitEventToJS("onHide", eventData: nil)
                self.isShowing = false
            })
        }
    }
    
    @objc(isValidFile:withResolver:withRejecter:)
    func isValidFile(uri: String, resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
        let fileURL = URL(string: uri)!
        checkFileValidity(url: fileURL) { isValid, fileType, duration in
            if isValid {
                print("Valid \(fileType) file with duration: \(duration) milliseconds")
            } else {
                print("Invalid file")
            }
            
            let payload: [String: Any] = [
                "isValid": isValid,
                "fileType": fileType,
                "duration": duration
            ]
            resolve(payload)
        }
        
    }
    
    private func onError(message: String, code: ErrorCode) {
        let eventPayload: [String: String] = [
            "message": message,
            "errorCode": code.rawValue
        ]
        self.emitEventToJS("onError", eventData: eventPayload)
    }
    
    private func checkFileValidity(url: URL, completion: @escaping (Bool, String, Double) -> Void) {
        let asset = AVAsset(url: url)
        
        // Load the duration and tracks asynchronously
        asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) {
            var error: NSError? = nil
            
            // Check if the duration and tracks are loaded
            let durationStatus = asset.statusOfValue(forKey: "duration", error: &error)
            let tracksStatus = asset.statusOfValue(forKey: "tracks", error: &error)
            
            // Ensure both properties are loaded successfully
            guard durationStatus == .loaded, tracksStatus == .loaded, error == nil else {
                DispatchQueue.main.async {
                    completion(false, "unknown", -1)
                }
                return
            }
            
            // Check if the asset contains any video or audio tracks
            let videoTracks = asset.tracks(withMediaType: .video)
            let audioTracks = asset.tracks(withMediaType: .audio)
            
            let isValid = !videoTracks.isEmpty || !audioTracks.isEmpty
            let fileType: String
            if !videoTracks.isEmpty {
                fileType = "video"
            } else if !audioTracks.isEmpty {
                fileType = "audio"
            } else {
                fileType = "unknown"
            }
            
            let duration = CMTimeGetSeconds(asset.duration) * 1000
            
            DispatchQueue.main.async {
                completion(isValid, fileType, isValid ? duration.rounded() : -1)
            }
        }
    }
}
