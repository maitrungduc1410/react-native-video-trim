import React
import Photos
import ffmpegkit

let FILE_PREFIX = "trimmedVideo"
let BEFORE_TRIM_PREFIX = "beforeTrim"

@objc(VideoTrimSwift)
public class VideoTrim: RCTEventEmitter, AssetLoaderDelegate, UIDocumentPickerDelegate {
  // MARK: instance private props
  private var isShowing = false
  private var vc: VideoTrimmerViewController?
  private var isVideoType = true
  private var outputFile: URL?
  private var editorConfig: NSDictionary?
  
  // MARK: base options
  private var saveToPhoto: Bool {
    get {
      return editorConfig?["saveToPhoto"] as! Bool
    }
  }
  private var removeAfterSavedToPhoto: Bool {
    get {
      return editorConfig?["removeAfterSavedToPhoto"] as! Bool
    }
  }
  private var removeAfterFailedToSavePhoto: Bool {
    get {
      return editorConfig?["removeAfterFailedToSavePhoto"] as! Bool
    }
  }
  private var removeAfterSavedToDocuments: Bool {
    get {
      return editorConfig?["removeAfterSavedToDocuments"] as! Bool
    }
  }
  private var removeAfterFailedToSaveDocuments: Bool {
    get {
      return editorConfig?["removeAfterFailedToSaveDocuments"] as! Bool
    }
  }
  private var removeAfterShared: Bool {
    get {
      return editorConfig?["removeAfterShared"] as! Bool
    }
  }
  private var removeAfterFailedToShare: Bool {
    get {
      return editorConfig?["removeAfterFailedToShare"] as! Bool
    }
  }
  private var enableRotation: Bool {
    get {
      return editorConfig?["enableRotation"] as! Bool
    }
  }
  private var rotationAngle: Double {
    get {
      return editorConfig?["rotationAngle"] as! Double
    }
  }
  
  // MARK: trimming with editor options
  private var trimmingText: String {
    get {
      return editorConfig?["trimmingText"] as! String
    }
  }
  private var enableCancelDialog: Bool {
    get {
      return editorConfig?["enableCancelDialog"] as! Bool
    }
  }
  private var cancelDialogTitle: String {
    get {
      return editorConfig?["cancelDialogTitle"] as! String
    }
  }
  private var cancelDialogMessage: String {
    get {
      return editorConfig?["cancelDialogMessage"] as! String
    }
  }
  private var cancelDialogCancelText: String {
    get {
      return editorConfig?["cancelDialogCancelText"] as! String
    }
  }
  private var cancelDialogConfirmText: String {
    get {
      return editorConfig?["cancelDialogConfirmText"] as! String
    }
  }
  private var enableSaveDialog: Bool {
    get {
      return editorConfig?["enableSaveDialog"] as! Bool
    }
  }
  private var saveDialogTitle: String {
    get {
      return editorConfig?["saveDialogTitle"] as! String
    }
  }
  private var saveDialogMessage: String {
    get {
      return editorConfig?["saveDialogMessage"] as! String
    }
  }
  private var saveDialogCancelText: String {
    get {
      return editorConfig?["saveDialogCancelText"] as! String
    }
  }
  private var saveDialogConfirmText: String {
    get {
      return editorConfig?["saveDialogConfirmText"] as! String
    }
  }
  private var fullScreenModalIOS: Bool {
    get {
      return editorConfig?["fullScreenModalIOS"] as! Bool
    }
  }
  private var cancelButtonText: String {
    get {
      return editorConfig?["cancelButtonText"] as! String
    }
  }
  private var saveButtonText: String {
    get {
      return editorConfig?["saveButtonText"] as! String
    }
  }
  private var outputExt: String {
    get {
      return editorConfig?["outputExt"] as! String
    }
  }
  private var openDocumentsOnFinish: Bool {
    get {
      return editorConfig?["openDocumentsOnFinish"] as! Bool
    }
  }
  private var openShareSheetOnFinish: Bool {
    get {
      return editorConfig?["openShareSheetOnFinish"] as! Bool
    }
  }
  private var closeWhenFinish: Bool {
    get {
      return editorConfig?["closeWhenFinish"] as! Bool
    }
  }
  private var enableCancelTrimming: Bool {
    get {
      return editorConfig?["enableCancelTrimming"] as! Bool
    }
  }
  
  private var cancelTrimmingButtonText: String {
    get {
      return editorConfig?["cancelTrimmingButtonText"] as! String
    }
  }
  private var enableCancelTrimmingDialog: Bool {
    get {
      return editorConfig?["enableCancelTrimmingDialog"] as! Bool
    }
  }
  private var cancelTrimmingDialogTitle: String {
    get {
      return editorConfig?["cancelTrimmingDialogTitle"] as! String
    }
  }
  private var cancelTrimmingDialogMessage: String {
    get {
      return editorConfig?["cancelTrimmingDialogMessage"] as! String
    }
  }
  private var cancelTrimmingDialogCancelText: String {
    get {
      return editorConfig?["cancelTrimmingDialogCancelText"] as! String
    }
  }
  private var cancelTrimmingDialogConfirmText: String {
    get {
      return editorConfig?["cancelTrimmingDialogConfirmText"] as! String
    }
  }
  private var alertOnFailToLoad: Bool {
    get {
      return editorConfig?["alertOnFailToLoad"] as! Bool
    }
  }
  private var alertOnFailTitle: String {
    get {
      return editorConfig?["alertOnFailTitle"] as! String
    }
  }
  private var alertOnFailMessage: String {
    get {
      return editorConfig?["alertOnFailMessage"] as! String
    }
  }
  private var alertOnFailCloseText: String {
    get {
      return editorConfig?["alertOnFailCloseText"] as! String
    }
  }
  
  @objc public weak var delegate: VideoTrimProtocol?
  @objc public var isNewArch = false

  
  
  // MARK: for old arch
  private var hasListeners = false
  
  @objc
  static public override func requiresMainQueueSetup() -> Bool {
    return false
  }
  
  public override func supportedEvents() -> [String]! {
    return ["VideoTrim"]
  }
  
  public override func startObserving() {
    hasListeners = true
  }
  
  public override func stopObserving() {
    hasListeners = false
  }
  
  
  private func emitEventToJS(_ eventName: String, eventData: [String: Any]?) {
    if isNewArch {
      delegate?.emitEventToJS(eventName: eventName, body: eventData)
    } else {
      if hasListeners {
        var modifiedEventData = eventData ?? [:] // If eventData is nil, create an empty dictionary
        modifiedEventData["name"] = eventName
        sendEvent(withName: "VideoTrim", body: modifiedEventData)
      }
    }
  }
  
  private static func deleteFile(url: URL) -> Int {
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
    vc?.pausePlayer()
    
    let timestamp = Int(Date().timeIntervalSince1970)
    let outputName = "\(FILE_PREFIX)_\(timestamp).\(outputExt)"
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
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
    progressAlert.setTitle(trimmingText)
    
    if enableCancelTrimming {
      progressAlert.setCancelTitle(cancelTrimmingButtonText)
      progressAlert.showCancelBtn()
      progressAlert.onDismiss = {
        if self.enableCancelTrimmingDialog {
          let dialogMessage = UIAlertController(title: self.cancelTrimmingDialogTitle, message: self.cancelTrimmingDialogMessage, preferredStyle: .alert)
          dialogMessage.overrideUserInterfaceStyle = .dark
          
          // Create OK button with action handler
          let ok = UIAlertAction(title: self.cancelDialogConfirmText, style: .destructive, handler: { (action) -> Void in
            
            if let ffmpegSession = ffmpegSession {
              ffmpegSession.cancel()
            } else {
              self.emitEventToJS("onCancelTrimming", eventData: nil)
            }
            
            progressAlert.dismiss(animated: true)
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
    
    var cmds = [
      "-ss",
      "\(startTime * 1000)ms",
      "-to",
      "\(endTime * 1000)ms",
    ]
    
    if enableRotation {
      cmds.append(contentsOf: ["-display_rotation", "\(rotationAngle)"])
    }
    
    cmds.append(contentsOf: [
      "-i",
      "\(inputFile)",
      "-c",
      "copy",
      "-metadata",
      "creation_time=\(dateTime)",
      outputFile!.absoluteString
    ])
    
    print("Command: ", cmds.joined(separator: " "))
    
    let eventPayload: [String: Any] = [
      "message": "Command: \(cmds.joined(separator: " "))"
    ]
    self.emitEventToJS("onLog", eventData: eventPayload)
    
    ffmpegSession = FFmpegKit.execute(withArgumentsAsync: cmds, withCompleteCallback: { session in
      
      // always hide progressAlert
      DispatchQueue.main.async {
        progressAlert.dismiss(animated: true)
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
                  let _ = VideoTrim.deleteFile(url: self.outputFile!)
                }
              } else {
                self.onError(message: "Failed to save edited video to Photo Library: \(error?.localizedDescription ?? "Unknown error")", code: .failToSaveToPhoto)
                if self.removeAfterFailedToSavePhoto {
                  let _ = VideoTrim.deleteFile(url: self.outputFile!)
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
        
        if self.closeWhenFinish {
          self.closeEditor(delay: 500)
        }
        
      } else if ReturnCode.isCancel(returnCode) {
        // CANCEL
        self.emitEventToJS("onCancelTrimming", eventData: nil)
      } else {
        // FAILURE
        self.onError(message: "Command failed with state \(String(describing: FFmpegKitConfig.sessionState(toString: state ?? .failed))) and rc \(String(describing: returnCode)).\(String(describing: session?.getFailStackTrace()))", code: .trimmingFailed)
        if self.closeWhenFinish {
          self.closeEditor(delay: 500)
        }
      }
      
      
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
          progressAlert.setProgress(Float(completePercentage))
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
  
  // New Arch
  @objc(trim:url:config:)
  public func _trim(inputFile: String, config: NSDictionary, completion: @escaping ([String: Any]) -> Void) {
    var destPath: URL?
    
    if inputFile.hasPrefix("http://") || inputFile.hasPrefix("https://") {
      destPath = URL(string: inputFile)
    } else {
      destPath = renameFile(at: URL(string: inputFile)!, newName: BEFORE_TRIM_PREFIX)
    }
    
    guard let destPath = destPath else {
      let result = [
        "success": false,
        "message": "Invalid input file path",
      ] as [String : Any]
      
      completion(result)
      
      return
    }
    
    let timestamp = Int(Date().timeIntervalSince1970)
    let outputExt = config["outputExt"] as? String ?? "mp4"
    let outputName = "\(FILE_PREFIX)_\(timestamp).\(outputExt)"
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let outputFile = documentsDirectory.appendingPathComponent(outputName)
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let dateTime = formatter.string(from: Date())
    
    let startTime = config["startTime"] as? Double ?? 0
    let endTime = config["endTime"] as? Double ?? 0
    var cmds = [
      "-ss",
      "\(startTime)ms",
      "-to",
      "\(endTime)ms",
    ]
    
    if let enableRotation = config["enableRotation"] as? Bool, enableRotation {
      let rotationAngle = config["rotationAngle"] as? Double ?? 0
      cmds.append(contentsOf: ["-display_rotation", "\(rotationAngle)"])
    }
    
    cmds.append(contentsOf: [
      "-i",
      "\(destPath.absoluteString)",
      "-c",
      "copy",
      "-metadata",
      "creation_time=\(dateTime)",
      outputFile.absoluteString
    ])
    
    print("Command: ", cmds.joined(separator: " "))
    
    FFmpegKit.execute(withArgumentsAsync: cmds, withCompleteCallback: { session in
      let returnCode = session?.getReturnCode()
      
      if ReturnCode.isSuccess(returnCode) {
        let result = [
          "success": true,
          "outputPath": outputFile.absoluteString,
          "startTime": startTime,
          "endTime": endTime
        ] as [String : Any]
        
        completion(result)
      } else if ReturnCode.isCancel(returnCode) {
        // CANCEL
        let result = [
          "success": false,
          "message": "FFmpeg command was cancelled with code \(returnCode?.getValue() ?? -1)",
        ] as [String : Any]
        
        completion(result)
      } else {
        // FAILURE
        let result = [
          "success": false,
          "message": "Command failed with rc \(String(describing: returnCode)).\(String(describing: session?.getFailStackTrace()))",
        ] as [String : Any]
        
        completion(result)
      }
    }, withLogCallback: nil, withStatisticsCallback: nil)
  }
  
  // Old Arch
  @objc(trim:withConfig:withResolver:withRejecter:)
  func _trim(inputFile: String, config: NSDictionary, resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
    _trim(inputFile: inputFile, config: config, completion: { payload in
      if let success = payload["success"] as? Bool, success {
        resolve(payload)
      } else {
        let message = payload["message"] as? String ?? "Unknown error"
        let error = NSError(domain: "", code: 200, userInfo: nil)
        reject("ERR_TRIM_FAILED", message, error)
      }
    })
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
            let _ = VideoTrim.deleteFile(url: self.outputFile!)
          }
          return
        }
        
        if completed {
          print("User completed the sharing activity")
          if self.removeAfterShared {
            let _ = VideoTrim.deleteFile(url: self.outputFile!)
          }
        } else {
          print("User cancelled or failed to complete the sharing activity")
          if self.removeAfterFailedToShare {
            let _ = VideoTrim.deleteFile(url: self.outputFile!)
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
  
  private func onError(message: String, code: ErrorCode) {
    let eventPayload: [String: String] = [
      "message": message,
      "errorCode": code.rawValue
    ]
    self.emitEventToJS("onError", eventData: eventPayload)
  }
  
  private func renameFile(at url: URL, newName: String) -> URL? {
    let fileManager = FileManager.default
    
    // Get the directory of the existing file
    let directory = url.deletingLastPathComponent()
    
    // Get the file extension
    let fileExtension = url.pathExtension
    
    // Create the new file URL with the new name and the same extension
    let newFileURL = directory.appendingPathComponent(newName).appendingPathExtension(fileExtension)
    
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

// MARK: @objc instance methods
extension VideoTrim {
  // Old + New arch
  @objc(showEditor:withConfig:)
  public func showEditor(uri: String, config: NSDictionary) {
    if isShowing {
      return
    }
    editorConfig = config
    
    //
    //    saveToPhoto = config["saveToPhoto"] as? Bool ?? false
    //
    //    removeAfterSavedToPhoto = config["removeAfterSavedToPhoto"] as? Bool ?? false
    //    removeAfterFailedToSavePhoto = config["removeAfterFailedToSavePhoto"] as? Bool ?? false
    //    removeAfterSavedToDocuments = config["removeAfterSavedToDocuments"] as? Bool ?? false
    //    removeAfterFailedToSaveDocuments = config["removeAfterFailedToSaveDocuments"] as? Bool ?? false
    //    removeAfterShared = config["removeAfterShared"] as? Bool ?? false
    //    removeAfterFailedToShare = config["removeAfterFailedToShare"] as? Bool ?? false
    //
    //    enableCancelDialog = config["enableCancelDialog"] as? Bool ?? true
    //    cancelDialogTitle = config["cancelDialogTitle"] as? String ?? "Warning!"
    //    cancelDialogMessage = config["cancelDialogMessage"] as? String ?? "Are you sure want to cancel?"
    //    cancelDialogCancelText = config["cancelDialogCancelText"] as? String ?? "Close"
    //    cancelDialogConfirmText = config["cancelDialogConfirmText"] as? String ?? "Proceed"
    //
    //    enableSaveDialog = config["enableSaveDialog"] as? Bool ?? true
    //    saveDialogTitle = config["saveDialogTitle"] as? String ?? "Confirmation!"
    //    saveDialogMessage = config["saveDialogMessage"] as? String ?? "Are you sure want to save?"
    //    saveDialogCancelText = config["saveDialogCancelText"] as? String ?? "Close"
    //    saveDialogConfirmText = config["saveDialogConfirmText"] as? String ?? "Proceed"
    //    trimmingText = config["trimmingText"] as? String ?? "Trimming video..."
    //    fullScreenModalIOS = config["fullScreenModalIOS"] as? Bool ?? false
    //    isVideoType = (config["type"] as? String ?? "video") == "video"
    //    outputExt = config["outputExt"] as? String ?? "mp4"
    //    openDocumentsOnFinish = config["openDocumentsOnFinish"] as? Bool ?? false
    //    openShareSheetOnFinish = config["openShareSheetOnFinish"] as? Bool ?? false
    //
    //    closeWhenFinish = config["closeWhenFinish"] as? Bool ?? true
    //    enableCancelTrimming = config["enableCancelTrimming"] as? Bool ?? true
    //    cancelTrimmingButtonText = config["cancelTrimmingButtonText"] as? String ?? "Cancel"
    //    enableCancelTrimmingDialog = config["enableCancelTrimmingDialog"] as? Bool ?? true
    //    cancelTrimmingDialogTitle = config["cancelTrimmingDialogTitle"] as? String ?? "Warning!"
    //    cancelTrimmingDialogMessage = config["cancelTrimmingDialogMessage"] as? String ?? "Are you sure want to cancel trimming?"
    //    cancelTrimmingDialogCancelText = config["cancelTrimmingDialogCancelText"] as? String ?? "Close"
    //    cancelTrimmingDialogConfirmText = config["cancelTrimmingDialogConfirmText"] as? String ?? "Proceed"
    //    alertOnFailToLoad = config["alertOnFailToLoad"] as? Bool ?? true
    //    alertOnFailTitle = config["alertOnFailTitle"] as? String ?? "Error"
    //    alertOnFailMessage = config["alertOnFailMessage"] as? String ?? "Fail to load media. Possibly invalid file or no network connection"
    //    alertOnFailCloseText = config["alertOnFailCloseText"] as? String ?? "Close"
    //
    //    if let cancelBtnText = config["cancelButtonText"] as? String, !cancelBtnText.isEmpty {
    //      self.cancelButtonText = cancelBtnText
    //    }
    //
    //    if let saveButtonText = config["saveButtonText"] as? String, !saveButtonText.isEmpty {
    //      self.saveButtonText = saveButtonText
    //    }
    
    var destPath: URL?
    
    if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
      destPath = URL(string: uri)
    } else {
      destPath = renameFile(at: URL(string: uri)!, newName: BEFORE_TRIM_PREFIX)
    }
    
    guard let destPath = destPath else { return }
    
    DispatchQueue.main.async {
      self.vc = VideoTrimmerViewController()
      
      guard let vc = self.vc else { return }
      
      vc.configure(config: config)
      
      vc.cancelBtnClicked = {
        if !self.enableCancelDialog {
          self.emitEventToJS("onCancel", eventData: nil)
          
          self.closeEditor()
          return
        }
        
        // Create Alert
        let dialogMessage = UIAlertController(title: self.cancelDialogTitle, message: self.cancelDialogMessage, preferredStyle: .alert)
        dialogMessage.overrideUserInterfaceStyle = .dark
        
        // Create OK button with action handler
        let ok = UIAlertAction(title: self.cancelDialogConfirmText, style: .destructive, handler: { (action) -> Void in
          self.emitEventToJS("onCancel", eventData: nil)
          self.closeEditor()
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
        dialogMessage.overrideUserInterfaceStyle = .dark
        
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
          
          // start loading asset after view is finished presenting
          // otherwise it may run too fast for local file and autoplay looks weird
          let assetLoader = AssetLoader()
          assetLoader.delegate = self
          assetLoader.loadAsset(url: destPath, isVideoType: self.isVideoType)
        })
      }
    }
  }
  
  // New Arch
  @objc(closeEditor:)
  public func closeEditor(delay: Int = 0) {
    guard let vc = vc else { return }
    // some how in case we trim a very short video the view controller is still visible after first .dismiss call
    // even the file is successfully saved
    // that's why we need a small delay here to ensure vc will be dismissed
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
      vc.dismiss(animated: true, completion: {
        self.emitEventToJS("onHide", eventData: nil)
        self.isShowing = false
      })
    }
  }
  
  // Old Arch
  @objc(closeEditor)
  func _closeEditor() -> Void {
    closeEditor()
  }
}

// MARK: @objc static methods
extension VideoTrim {
  // New Arch
  @objc(listFiles)
  public static func _listFiles() -> [String] {
    return listFiles().map{ $0.absoluteString }
  }
  
  // Old Arch
  @objc(listFiles:withRejecter:)
  func listFiles(resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
    resolve(VideoTrim._listFiles())
  }
  
  // New Arch
  @objc(cleanFiles)
  public static func cleanFiles() -> Int {
    let files = listFiles()
    var successCount = 0
    for file in files {
      let state = deleteFile(url: file)
      
      if state == 0 {
        successCount += 1
      }
    }
    
    return successCount
  }
  
  // Old Arch
  @objc(cleanFiles:withRejecter:)
  func cleanFiles(resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
    resolve(VideoTrim.cleanFiles())
  }
  
  // New Arch
  @objc(deleteFile:)
  public static func deleteFile(uri: String) -> Bool {
    let state = deleteFile(url: URL(string: uri)!)
    return state == 0
  }
  
  // Old Arch
  @objc(deleteFile:withResolver:withRejecter:)
  func deleteFile(uri: String, resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
    resolve(VideoTrim.deleteFile(uri: uri))
  }
  
  private static func listFiles() -> [URL] {
    var files: [URL] = []
    
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    do {
      let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
      
      for fileURL in directoryContents {
        if fileURL.lastPathComponent.starts(with: FILE_PREFIX) || fileURL.lastPathComponent.starts(with: BEFORE_TRIM_PREFIX) {
          files.append(fileURL)
        }
      }
    } catch {
      print("[listFiles] Error when retrieving files: \(error)")
    }
    
    return files
  }
  
  // New Arch
  @objc(isValidFile:url:)
  public static func isValidFile(url: String, completion: @escaping ([String: Any]) -> Void) -> Void {
    let fileURL = URL(string: url)!
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
      
      completion(payload)
    }
  }
  
  // Old Arch
  @objc(isValidFile:withResolver:withRejecter:)
  func isValidFile(uri: String, resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock) -> Void {
    VideoTrim.isValidFile(url: uri, completion: { payload in
        resolve(payload)
      }
    )
  }
  
  private static func checkFileValidity(url: URL, completion: @escaping (Bool, String, Double) -> Void) {
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
      
      //      DispatchQueue.main.async {
      completion(isValid, fileType, isValid ? duration.rounded() : -1)
      //      }
    }
  }
}

// MARK: Delegates
// MARK: AssetLoader delegate
extension VideoTrim {
  func assetLoader(_ loader: AssetLoader, didFailWithError error: any Error, forKey key: String) {
    let message = "Failed to load \(key): \(error.localizedDescription)"
    print("Failed to load \(key)", message)
    
    self.onError(message: message, code: .failToLoadMedia)
    vc?.onAssetFailToLoad()
    
    if alertOnFailToLoad {
      let dialogMessage = UIAlertController(title: alertOnFailTitle, message: alertOnFailMessage, preferredStyle: .alert)
      dialogMessage.overrideUserInterfaceStyle = .dark
      
      // Create Cancel button with action handlder
      let ok = UIAlertAction(title: alertOnFailCloseText, style: .default)
      
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
    
    let eventPayload: [String: Any] = [
      "duration": loader.asset!.duration.seconds * 1000,
    ]
    self.emitEventToJS("onLoad", eventData: eventPayload)
  }
}


// MARK: DocumentPicker delegate
extension VideoTrim {
  public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    if removeAfterSavedToDocuments {
      let _ = VideoTrim.deleteFile(url: outputFile!)
    }
    closeEditor()
  }
  
  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    if removeAfterFailedToSaveDocuments {
      let _ = VideoTrim.deleteFile(url: outputFile!)
    }
    closeEditor()
  }
}
