//
//  VideoTrimImpl.swift
//  VideoTrim
//
//  Created by Duc Trung Mai on 21/5/25.
//

import Photos
import ffmpegkit

class VideoTrimImpl: NSObject
{
    private let FILE_PREFIX = "trimmedVideo"
    private var isShowing = false
    private var vc: VideoTrimmerViewController?
    private var outputFile: URL?
    
//    private var saveToPhoto = false
//    private var removeAfterSavedToPhoto = false
//    private var removeAfterFailedToSavePhoto = false
//    private var removeAfterSavedToDocuments = false
//    private var removeAfterFailedToSaveDocuments = false
//    private var removeAfterShared = false
//    private var removeAfterFailedToShare = false
//    
//    private var trimmingText = "Trimming video..."
//    private var enableCancelDialog = true
//    private var cancelDialogTitle = "Warning!"
//    private var cancelDialogMessage = "Are you sure want to cancel?"
//    private var cancelDialogCancelText = "Close"
//    private var cancelDialogConfirmText = "Proceed"
//    private var enableSaveDialog = true
//    private var saveDialogTitle = "Confirmation!"
//    private var saveDialogMessage = "Are you sure want to save?"
//    private var saveDialogCancelText = "Close"
//    private var saveDialogConfirmText = "Proceed"
//    private var fullScreenModalIOS = false
//    private var cancelButtonText = "Cancel"
//    private var saveButtonText = "Save"

    private var isVideoType = true
//    private var outputExt = "mp4"
//    private var openDocumentsOnFinish = false
//    private var openShareSheetOnFinish = false

//    private var closeWhenFinish = true
//    private var enableCancelTrimming = true
//    private var cancelTrimmingButtonText = "Cancel"
//    private var enableCancelTrimmingDialog = true
//    private var cancelTrimmingDialogTitle = "Warning!"
//    private var cancelTrimmingDialogMessage = "Are you sure want to trimming?"
//    private var cancelTrimmingDialogCancelText = "Close"
//    private var cancelTrimmingDialogConfirmText = "Proceed"
//    private var alertOnFailToLoad = true
//    private var alertOnFailTitle = "Error"
//    private var alertOnFailMessage =
//    "Fail to load media. Possibly invalid file or no network connection"
//    private var alertOnFailCloseText = "Close"
    private var editorConfig: EditorConfig!
    
    private var onEvent: ((_ eventName: String, _ payload: Dictionary<String, String>) -> Void)?
    
    func showEditor(
        uri: String,
        editorConfig: EditorConfig,
        onEvent: ((_ eventName: String, _ payload: Dictionary<String, String>) -> Void)?
    ) {
        if isShowing {
            return
        }
        
        self.editorConfig = editorConfig
        self.onEvent = onEvent
        //    saveToPhoto = config["saveToPhoto"] as? Bool ?? false
        //
        //    removeAfterSavedToPhoto =
        //      config["removeAfterSavedToPhoto"] as? Bool ?? false
        //    removeAfterFailedToSavePhoto =
        //      config["removeAfterFailedToSavePhoto"] as? Bool ?? false
        //    removeAfterSavedToDocuments =
        //      config["removeAfterSavedToDocuments"] as? Bool ?? false
        //    removeAfterFailedToSaveDocuments =
        //      config["removeAfterFailedToSaveDocuments"] as? Bool ?? false
        //    removeAfterShared = config["removeAfterShared"] as? Bool ?? false
        //    removeAfterFailedToShare =
        //      config["removeAfterFailedToShare"] as? Bool ?? false
        //
        //    enableCancelDialog = config["enableCancelDialog"] as? Bool ?? true
        //    cancelDialogTitle = config["cancelDialogTitle"] as? String ?? "Warning!"
        //    cancelDialogMessage =
        //      config["cancelDialogMessage"] as? String ?? "Are you sure want to cancel?"
        //    cancelDialogCancelText =
        //      config["cancelDialogCancelText"] as? String ?? "Close"
        //    cancelDialogConfirmText =
        //      config["cancelDialogConfirmText"] as? String ?? "Proceed"
        //
        //    enableSaveDialog = config["enableSaveDialog"] as? Bool ?? true
        //    saveDialogTitle = config["saveDialogTitle"] as? String ?? "Confirmation!"
        //    saveDialogMessage =
        //      config["saveDialogMessage"] as? String ?? "Are you sure want to save?"
        //    saveDialogCancelText = config["saveDialogCancelText"] as? String ?? "Close"
        //    saveDialogConfirmText =
        //      config["saveDialogConfirmText"] as? String ?? "Proceed"
        //    trimmingText = config["trimmingText"] as? String ?? "Trimming video..."
        //    fullScreenModalIOS = config["fullScreenModalIOS"] as? Bool ?? false
        isVideoType = editorConfig.type == "video"
        //    outputExt = config["outputExt"] as? String ?? "mp4"
        //    openDocumentsOnFinish = config["openDocumentsOnFinish"] as? Bool ?? false
        //    openShareSheetOnFinish = config["openShareSheetOnFinish"] as? Bool ?? false
        //
        //    closeWhenFinish = config["closeWhenFinish"] as? Bool ?? true
        //    enableCancelTrimming = config["enableCancelTrimming"] as? Bool ?? true
        //    cancelTrimmingButtonText =
        //      config["cancelTrimmingButtonText"] as? String ?? "Cancel"
        //    enableCancelTrimmingDialog =
        //      config["enableCancelTrimmingDialog"] as? Bool ?? true
        //    cancelTrimmingDialogTitle =
        //      config["cancelTrimmingDialogTitle"] as? String ?? "Warning!"
        //    cancelTrimmingDialogMessage =
        //      config["cancelTrimmingDialogMessage"] as? String
        //      ?? "Are you sure want to cancel trimming?"
        //    cancelTrimmingDialogCancelText =
        //      config["cancelTrimmingDialogCancelText"] as? String ?? "Close"
        //    cancelTrimmingDialogConfirmText =
        //      config["cancelTrimmingDialogConfirmText"] as? String ?? "Proceed"
        //    alertOnFailToLoad = config["alertOnFailToLoad"] as? Bool ?? true
        //    alertOnFailTitle = config["alertOnFailTitle"] as? String ?? "Error"
        //    alertOnFailMessage =
        //      config["alertOnFailMessage"] as? String
        //      ?? "Fail to load media. Possibly invalid file or no network connection"
        //    alertOnFailCloseText = config["alertOnFailCloseText"] as? String ?? "Close"
        //
        //    if let cancelBtnText = config["cancelButtonText"] as? String,
        //      !cancelBtnText.isEmpty
        //    {
        //      self.cancelButtonText = cancelBtnText
        //    }
        //
        //    if let saveButtonText = config["saveButtonText"] as? String,
        //      !saveButtonText.isEmpty
        //    {
        //      self.saveButtonText = saveButtonText
        //    }
        //
        let destPath = URL(string: uri)
        let newPath = renameFile(at: destPath!, newName: "beforeTrim")
        
        guard let destPath = newPath else {
            onError(message: "Fail to rename file", code: .invalidFilePath)
            self.isShowing = false
            return
        }
        
        DispatchQueue.main.async {
            self.vc = VideoTrimmerViewController()
            
            guard let vc = self.vc else { return }
            
            vc.configure(config: editorConfig)
            
            vc.cancelBtnClicked = {
                if !self.editorConfig.enableCancelDialog {
                    self.emitEventToJS("onCancel", eventData: nil)
                    
                    vc.dismiss(
                        animated: true,
                        completion: {
                            self.emitEventToJS("onHide", eventData: nil)
                            self.isShowing = false
                        })
                    return
                }
                
                // Create Alert
                let dialogMessage = UIAlertController(
                    title: self.editorConfig.cancelDialogTitle, message: self.editorConfig.cancelDialogMessage,
                    preferredStyle: .alert)
                dialogMessage.overrideUserInterfaceStyle = .dark
                
                // Create OK button with action handler
                let ok = UIAlertAction(
                    title: self.editorConfig.cancelDialogConfirmText, style: .destructive,
                    handler: { (action) -> Void in
                        self.emitEventToJS("onCancel", eventData: nil)
                        
                        vc.dismiss(
                            animated: true,
                            completion: {
                                self.emitEventToJS("onHide", eventData: nil)
                                self.isShowing = false
                            })
                    })
                
                // Create Cancel button with action handlder
                let cancel = UIAlertAction(
                    title: self.editorConfig.cancelDialogCancelText, style: .cancel)
                
                //Add OK and Cancel button to an Alert object
                dialogMessage.addAction(ok)
                dialogMessage.addAction(cancel)
                
                // Present alert message to user
                if let root = RCTPresentedViewController() {
                    root.present(dialogMessage, animated: true, completion: nil)
                    
                }
                
            }
            
            vc.saveBtnClicked = { (selectedRange: CMTimeRange) in
                if !self.editorConfig.enableSaveDialog {
                    self.trim(
                        viewController: vc, inputFile: destPath,
                        videoDuration: self.vc!.asset!.duration.seconds,
                        startTime: selectedRange.start.seconds,
                        endTime: selectedRange.end.seconds)
                    return
                }
                
                // Create Alert
                let dialogMessage = UIAlertController(
                    title: self.editorConfig.saveDialogTitle, message: self.editorConfig.saveDialogMessage,
                    preferredStyle: .alert)
                dialogMessage.overrideUserInterfaceStyle = .dark
                
                // Create OK button with action handler
                let ok = UIAlertAction(
                    title: self.editorConfig.saveDialogConfirmText, style: .default,
                    handler: { (action) -> Void in
                        self.trim(
                            viewController: vc, inputFile: destPath,
                            videoDuration: vc.asset!.duration.seconds,
                            startTime: selectedRange.start.seconds,
                            endTime: selectedRange.end.seconds)
                    })
                
                // Create Cancel button with action handlder
                let cancel = UIAlertAction(
                    title: self.editorConfig.saveDialogCancelText, style: .cancel)
                
                //Add OK and Cancel button to an Alert object
                dialogMessage.addAction(ok)
                dialogMessage.addAction(cancel)
                
                // Present alert message to user
                if let root = RCTPresentedViewController() {
                    root.present(dialogMessage, animated: true, completion: nil)
                }
               
                
            }
            
            vc.isModalInPresentation = true  // prevent modal closed by swipe down
            
            if editorConfig.fullScreenModalIOS {
                vc.modalPresentationStyle = .fullScreen
            }
            
            if let root = RCTPresentedViewController() {
                root.present(
                    vc, animated: true,
                    completion: {
                        self.emitEventToJS("onShow", eventData: nil)
                        self.isShowing = true
                        
                        // start loading asset after view is finished presenting
                        // otherwise it may run too fast for local file and autoplay looks weird
                        let assetLoader = AssetLoader()
                        assetLoader.delegate = self
                        assetLoader.loadAsset(url: destPath, isVideoType: self.isVideoType)
                    })
            }
            
            
        }
        
    }
    
    private func copyFileToDocumentDir(uri: String) -> URL? {
        if let videoURL = URL(string: uri) {
            // Save the video to the document directory
            let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first!
            // Extract the file extension from the videoURL
            let fileExtension = videoURL.pathExtension
            
            // Define the filename with the correct file extension
            let timestamp = Int(Date().timeIntervalSince1970)
            let destinationURL = documentsDirectory.appendingPathComponent(
                "\(FILE_PREFIX)_original_\(timestamp).\(fileExtension)")
            
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
    
    private func emitEventToJS(_ eventName: String, eventData: [String: String]?) {
        onEvent?(eventName, eventData ?? [:])
    }
    
    func listFiles() -> [URL] {
        var files: [URL] = []
        
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
        
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(
                at: documentsDirectory, includingPropertiesForKeys: nil)
            
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
    
    func deleteFile(url: URL) -> Int {
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
    
    private func trim(
        viewController: VideoTrimmerViewController, inputFile: URL,
        videoDuration: Double, startTime: Double, endTime: Double
    ) {
        vc?.pausePlayer()
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let outputName = "\(FILE_PREFIX)_\(timestamp).\(editorConfig.outputExt)"
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
        outputFile = documentsDirectory.appendingPathComponent(outputName)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateTime = formatter.string(from: Date())
        
        emitEventToJS("onStartTrimming", eventData: nil)
        
        var ffmpegSession: FFmpegSession?
        let progressAlert = ProgressAlertController()
        progressAlert.modalPresentationStyle = .overFullScreen
        progressAlert.modalTransitionStyle = .crossDissolve
        progressAlert.setTitle(editorConfig.trimmingText)
        
        if editorConfig.enableCancelTrimming {
            progressAlert.setCancelTitle(editorConfig.cancelTrimmingButtonText)
            progressAlert.showCancelBtn()
            progressAlert.onDismiss = {
                if self.editorConfig.enableCancelTrimmingDialog {
                    let dialogMessage = UIAlertController(
                        title: self.editorConfig.cancelTrimmingDialogTitle,
                        message: self.editorConfig.cancelTrimmingDialogMessage, preferredStyle: .alert)
                    dialogMessage.overrideUserInterfaceStyle = .dark
                    
                    // Create OK button with action handler
                    let ok = UIAlertAction(
                        title: self.editorConfig.cancelDialogConfirmText, style: .destructive,
                        handler: { (action) -> Void in
                            
                            if let ffmpegSession = ffmpegSession {
                                ffmpegSession.cancel()
                            } else {
                                self.emitEventToJS("onCancelTrimming", eventData: nil)
                            }
                            
                            progressAlert.dismiss(animated: true)
                        })
                    
                    // Create Cancel button with action handlder
                    let cancel = UIAlertAction(
                        title: self.editorConfig.cancelDialogCancelText, style: .cancel)
                    
                    //Add OK and Cancel button to an Alert object
                    dialogMessage.addAction(ok)
                    dialogMessage.addAction(cancel)
                    
                    // Present alert message to user
                    if let root = RCTPresentedViewController() {
                        root.present(dialogMessage, animated: true, completion: nil)
                    }
                    
                    
                } else {
                    if let ffmpegSession = ffmpegSession {
                        ffmpegSession.cancel()
                    } else {
                        self.emitEventToJS("onCancelTrimming", eventData: nil)
                    }
                    
                    progressAlert.dismiss(animated: true)
                }
                
            }
        }
        
        if let root = RCTPresentedViewController() {
            root.present(progressAlert, animated: true, completion: nil)
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
            outputFile!.absoluteString,
        ]
        
        print("Command: ", cmds.joined(separator: " "))
        
        let eventPayload: [String: String] = [
            "command": cmds.joined(separator: " ")
        ]
        self.emitEventToJS("onLog", eventData: eventPayload)
        
        ffmpegSession = FFmpegKit.execute(
            withArgumentsAsync: cmds,
            withCompleteCallback: { session in
                
                // always hide progressAlert
                DispatchQueue.main.async {
                    // need to wait for it to fully dimissed before presenting new viewcontroller
                    progressAlert.dismiss(animated: true, completion: {
                        DispatchQueue.global(qos: .default).async {
                            let state = session?.getState()
                            let returnCode = session?.getReturnCode()
                            
                            if ReturnCode.isSuccess(returnCode) {
                                let eventPayload: [String: String] = [
                                    "outputPath": self.outputFile!.absoluteString,
                                    "startTime": String((startTime * 1000).rounded()),
                                    "endTime": String((endTime * 1000).rounded()),
                                    "duration": String((videoDuration * 1000).rounded()),
                                ]
                                self.emitEventToJS("onFinishTrimming", eventData: eventPayload)
                                
                                if self.editorConfig.saveToPhoto && self.isVideoType {
                                    PHPhotoLibrary.requestAuthorization { status in
                                        guard status == .authorized else {
                                            self.onError(
                                                message: "Permission to access Photo Library is not granted",
                                                code: .noPhotoPermission)
                                            return
                                        }
                                        
                                        PHPhotoLibrary.shared().performChanges({
                                            let request =
                                            PHAssetChangeRequest.creationRequestForAssetFromVideo(
                                                atFileURL: self.outputFile!)
                                            request?.creationDate = Date()
                                        }) { success, error in
                                            if success {
                                                print("Edited video saved to Photo Library successfully.")
                                                
                                                if self.editorConfig.removeAfterSavedToPhoto {
                                                    let _ = self.deleteFile(url: self.outputFile!)
                                                }
                                            } else {
                                                self.onError(
                                                    message:
                                                        "Failed to save edited video to Photo Library: \(error?.localizedDescription ?? "Unknown error")",
                                                    code: .failToSaveToPhoto)
                                                if self.editorConfig.removeAfterFailedToSavePhoto {
                                                    let _ = self.deleteFile(url: self.outputFile!)
                                                }
                                            }
                                        }
                                    }
                                } else if self.editorConfig.openDocumentsOnFinish {
                                    self.saveFileToFilesApp(fileURL: self.outputFile!)
                                    
                                    // must return otherwise editor will close
                                    return
                                } else if self.editorConfig.openShareSheetOnFinish {
                                    self.shareFile(fileURL: self.outputFile!)
                                    
                                    // must return otherwise editor will close
                                    return
                                }
                                
                                if self.editorConfig.closeWhenFinish {
                                    self.closeEditor()
                                }
                                
                            } else if ReturnCode.isCancel(returnCode) {
                                // CANCEL
                                self.emitEventToJS("onCancelTrimming", eventData: nil)
                            } else {
                                // FAILURE
                                self.onError(
                                    message:
                                        "Command failed with state \(String(describing: FFmpegKitConfig.sessionState(toString: state ?? .failed))) and rc \(String(describing: returnCode)).\(String(describing: session?.getFailStackTrace()))",
                                    code: .trimmingFailed)
                                if self.editorConfig.closeWhenFinish {
                                    self.closeEditor()
                                }
                            }
                        }
                    })
                }
            },
            withLogCallback: { log in
                guard let log = log else { return }
                
                print("FFmpeg process started with log " + (log.getMessage()))
                
                let eventPayload: [String: String] = [
                    "level": String(log.getLevel()),
                    "message": log.getMessage() ?? "",
                    "sessionId": String(log.getSessionId()),
                ]
                self.emitEventToJS("onLog", eventData: eventPayload)
                
            },
            withStatisticsCallback: { statistics in
                guard let statistics = statistics else { return }
                
                let timeInMilliseconds = statistics.getTime()
                if timeInMilliseconds > 0 {
                    let completePercentage = timeInMilliseconds / (videoDuration * 1000)  // from 0 -> 1
                    DispatchQueue.main.async {
                        progressAlert.setProgress(Float(completePercentage))
                    }
                }
                
                let eventPayload: [String: String] = [
                    "sessionId": String(statistics.getSessionId()),
                    "videoFrameNumber": String(statistics.getVideoFrameNumber()),
                    "videoFps": String(statistics.getVideoFps()),
                    "videoQuality": String(statistics.getVideoQuality()),
                    "size": String(statistics.getSize()),
                    "time": String(statistics.getTime()),
                    "bitrate": String(statistics.getBitrate()),
                    "speed": String(statistics.getSpeed()),
                ]
                self.emitEventToJS("onStatistics", eventData: eventPayload)
            })
    }
    
    private func saveFileToFilesApp(fileURL: URL) {
        DispatchQueue.main.async {
            let documentPicker = UIDocumentPickerViewController(
                url: fileURL, in: .exportToService)
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
            let activityViewController = UIActivityViewController(
                activityItems: [fileURL], applicationActivities: nil)
            
            activityViewController.completionWithItemsHandler = {
                activityType, completed, returnedItems, error in
                
                if let error = error {
                    let message = "Sharing error: \(error.localizedDescription)"
                    print(message)
                    self.onError(message: message, code: .failToShare)
                    
                    if self.editorConfig.removeAfterFailedToShare {
                        let _ = self.deleteFile(url: self.outputFile!)
                    }
                    return
                }
                
                if completed {
                    print("User completed the sharing activity")
                    if self.editorConfig.removeAfterShared {
                        let _ = self.deleteFile(url: self.outputFile!)
                    }
                } else {
                    print("User cancelled or failed to complete the sharing activity")
                    if self.editorConfig.removeAfterFailedToShare {
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
    
    func closeEditor(_ onComplete: (() -> Void)? = nil) {
        guard let vc = vc else { return }
        // some how in case we trim a very short video the view controller is still visible after first .dismiss call
        // even the file is successfully saved
        // that's why we need a small delay here to ensure vc will be dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            vc.dismiss(
                animated: true,
                completion: {
//                    self.emitEventToJS("onHide", eventData: ["": ""])
                    onComplete?()
                    self.isShowing = false
                })
        }
    }
    
    func isValidFile(uri: String) async -> FileValidationResult {
        let fileURL = URL(string: uri)!
        let result = await checkFileValidity(url: fileURL)
        
        if result.isValid {
            print("Valid \(result.fileType) file with duration: \(result.duration) milliseconds")
        } else {
            print("Invalid file")
        }
        
        return FileValidationResult(isValid: result.isValid, fileType: result.fileType, duration: result.duration)
    }
    
    private func onError(message: String, code: ErrorCode) {
        let eventPayload: [String: String] = [
            "message": message,
            "errorCode": code.rawValue,
        ]
        self.emitEventToJS("onError", eventData: eventPayload)
    }
    
    private func checkFileValidity(url: URL) async -> FileValidationResult {
        let asset = AVAsset(url: url)
        
        do {
            // Load duration and tracks asynchronously
            let (duration, tracks) = try await asset.load(.duration, .tracks)
            // Check for video or audio tracks
            let videoTracks = tracks.filter { $0.mediaType == .video }
            let audioTracks = tracks.filter { $0.mediaType == .audio }
            
            let isValid = !videoTracks.isEmpty || !audioTracks.isEmpty
            let fileType: String
            if !videoTracks.isEmpty {
                fileType = "video"
            } else if !audioTracks.isEmpty {
                fileType = "audio"
            } else {
                fileType = "unknown"
            }
            
            let durationMs = CMTimeGetSeconds(duration) * 1000
            
            return FileValidationResult(
                isValid: isValid,
                fileType: fileType,
                duration: isValid ? durationMs.rounded() : -1
            )
        } catch {
            return FileValidationResult(isValid: false, fileType: "unknown", duration: -1)
        }
        
    }
    
    private func renameFile(at url: URL, newName: String) -> URL? {
        let fileManager = FileManager.default
        
        // Get the directory of the existing file
        let directory = url.deletingLastPathComponent()
        
        // Get the file extension
        let fileExtension = url.pathExtension
        
        // Create the new file URL with the new name and the same extension
        let newFileURL = directory.appendingPathComponent(newName)
            .appendingPathExtension(fileExtension)
        
        // Check if a file with the new name already exists
        if fileManager.fileExists(atPath: newFileURL.path) {
            do {
                // If the file exists, remove it first to avoid conflicts
                try fileManager.removeItem(at: newFileURL)
            } catch {
                print("Error removing existing file: \(error)")
                return nil
            }
        }
        
        do {
            // Rename (move) the file
            try fileManager.moveItem(at: url, to: newFileURL)
            print("File renamed successfully to \(newFileURL.absoluteString)")
            return newFileURL
        } catch {
            print("Error renaming file: \(error)")
            return nil
        }
    }
}

extension VideoTrimImpl: AssetLoaderDelegate {
    func assetLoader(
        _ loader: AssetLoader, didFailWithError error: any Error, forKey key: String
    ) {
        let message = "Failed to load \(key): \(error.localizedDescription)"
        print("Failed to load \(key)", message)
        
        self.onError(message: message, code: .failToLoadMedia)
        vc?.onAssetFailToLoad()
        
        if editorConfig.alertOnFailToLoad {
            let dialogMessage = UIAlertController(
                title: editorConfig.alertOnFailTitle, message: editorConfig.alertOnFailMessage,
                preferredStyle: .alert)
            dialogMessage.overrideUserInterfaceStyle = .dark
            
            // Create Cancel button with action handlder
            let ok = UIAlertAction(title: editorConfig.alertOnFailCloseText, style: .default)
            
            //Add OK and Cancel button to an Alert object
            dialogMessage.addAction(ok)
            
            // Present alert message to user
            
            if let root = RCTPresentedViewController() {
                root.present(dialogMessage, animated: true, completion: nil)
            }
        }
    }
    
    func assetLoaderDidSucceed(_ loader: AssetLoader) {
        print("Asset loaded successfully")
        
        vc?.asset = loader.asset
        
        let eventPayload: [String: String] = [
            "duration": String(loader.asset!.duration.seconds * 1000)
        ]
        self.emitEventToJS("onLoad", eventData: eventPayload)
    }
}

extension VideoTrimImpl: UIDocumentPickerDelegate {
    func documentPicker(
        _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
        if editorConfig.removeAfterSavedToDocuments {
            let _ = deleteFile(url: outputFile!)
        }
        closeEditor()
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
    {
        if editorConfig.removeAfterFailedToSaveDocuments {
            let _ = deleteFile(url: outputFile!)
        }
        closeEditor()
    }
}

// Because somehow we can't import React here to swift (podspec React-Core or bridging header doesn't work)
// hence we'll need to reimplement RCTPresentedViewController

// Equivalent to RCTSharedApplication
func RCTSharedApplication() -> UIApplication? {
    // Safely access the shared UIApplication instance
    return UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? UIApplication
}

// Equivalent to RCTKeyWindow
func RCTKeyWindow() -> UIWindow? {
    guard let sharedApp = RCTSharedApplication() else {
        return nil
    }
    
    let connectedScenes = sharedApp.connectedScenes
    var foregroundActiveScene: UIScene?
    var foregroundInactiveScene: UIScene?
    
    for scene in connectedScenes {
        guard scene is UIWindowScene else {
            continue
        }
        
        if scene.activationState == .foregroundActive {
            foregroundActiveScene = scene
            break
        }
        
        if foregroundInactiveScene == nil && scene.activationState == .foregroundInactive {
            foregroundInactiveScene = scene
        }
    }
    
    let sceneToUse = foregroundActiveScene ?? foregroundInactiveScene
    
    if let windowScene = sceneToUse as? UIWindowScene {
        return windowScene.keyWindow
    }
    
    return nil
}

// Equivalent to RCTPresentedViewController
func RCTPresentedViewController() -> UIViewController? {
    guard let rootController = RCTKeyWindow()?.rootViewController else {
        return nil
    }
    
    var controller = rootController
    var presentedController = controller.presentedViewController
    
    while presentedController != nil && !presentedController!.isBeingDismissed {
        controller = presentedController!
        presentedController = controller.presentedViewController
    }
    
    return controller
}
