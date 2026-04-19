import React
import Photos
import AVFoundation
import ffmpegkit

let FILE_PREFIX = "trimmedVideo"

@objc(VideoTrimSwift)
public class VideoTrim: RCTEventEmitter, AssetLoaderDelegate, UIDocumentPickerDelegate {
  // MARK: instance private props
  private var isShowing = false
  private var isTrimming = false
  private var vc: VideoTrimmerViewController?
  private var outputFile: URL?
  private var editorConfig: NSDictionary?
  private var isLightTheme: Bool {
    return (editorConfig?["theme"] as? String) == "light"
  }
  
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
  
  /// When true, forces re-encoding even when no transforms are applied,
  /// giving frame-accurate trim points instead of keyframe-aligned cuts.
  private var enablePreciseTrimming: Bool {
    get {
      return editorConfig?["enablePreciseTrimming"] as? Bool ?? false
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
  
  private func trim(viewController: VideoTrimmerViewController, inputFile: URL, videoDuration: Double, startTime: Double, endTime: Double, isVideoType: Bool) {
    guard !isTrimming else { return }
    isTrimming = true

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
          dialogMessage.overrideUserInterfaceStyle = self.isLightTheme ? .light : .dark
          
          // Create OK button with action handler
          let ok = UIAlertAction(title: self.cancelTrimmingDialogConfirmText, style: .destructive, handler: { (action) -> Void in
            
            if let ffmpegSession = ffmpegSession {
              ffmpegSession.cancel()
            } else {
              self.emitEventToJS("onCancelTrimming", eventData: nil)
            }
            
            progressAlert.dismiss(animated: true) {
              self.isTrimming = false
            }
          })
          
          // Create Cancel button with action handlder
          let cancel = UIAlertAction(title: self.cancelTrimmingDialogCancelText, style: .cancel)
          
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
          
          progressAlert.dismiss(animated: true) {
            self.isTrimming = false
          }
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
    
    var videoFilters: [String] = []
    let hasUserTransform = vc != nil && (vc!.rotationCount != 0 || vc!.isFlipped)
    let cropNorm = vc?.cropNormalizedRect
    // Re-encode is required when: (1) user applied flip/rotate, (2) user cropped, or
    // (3) enablePreciseTrimming is on. In all three cases, -c copy won't work because
    // either we need video filters or we need frame-accurate cut points.
    let needsReEncode = hasUserTransform || cropNorm != nil || enablePreciseTrimming
    
    if needsReEncode, let vc = vc {
      // -noautorotate disables FFmpeg's automatic rotation, so we must manually
      // compensate for the source video's rotation metadata via transpose filters.
      if let asset = vc.asset,
         let videoTrack = asset.tracks(withMediaType: .video).first {
        let t = videoTrack.preferredTransform
        let sourceAngle = atan2(t.b, t.a)
        if abs(sourceAngle - .pi / 2) < 0.1 {
          videoFilters.append("transpose=1")
        } else if abs(sourceAngle + .pi / 2) < 0.1 {
          videoFilters.append("transpose=2")
        } else if abs(abs(sourceAngle) - .pi) < 0.1 {
          videoFilters.append("transpose=1")
          videoFilters.append("transpose=1")
        }
      }
      
      switch vc.rotationCount {
      case 1: videoFilters.append("transpose=2")
      case 2:
        videoFilters.append("transpose=2")
        videoFilters.append("transpose=2")
      case 3: videoFilters.append("transpose=1")
      default: break
      }
      if vc.isFlipped {
        videoFilters.append("hflip")
      }
      
      if let cn = cropNorm, let asset = vc.asset,
         let track = asset.tracks(withMediaType: .video).first {
        let raw = track.naturalSize
        let pt = track.preferredTransform
        let angle = atan2(pt.b, pt.a)
        let isSrcRotated = abs(angle - .pi / 2) < 0.1 || abs(angle + .pi / 2) < 0.1
        let corrected = isSrcRotated
            ? CGSize(width: raw.height, height: raw.width)
            : raw
        
        let postW: CGFloat
        let postH: CGFloat
        if vc.rotationCount % 2 != 0 {
          postW = corrected.height
          postH = corrected.width
        } else {
          postW = corrected.width
          postH = corrected.height
        }
        
        let cx = Int(round(cn.origin.x * postW))
        let cy = Int(round(cn.origin.y * postH))
        var cw = Int(round(cn.size.width * postW))
        var ch = Int(round(cn.size.height * postH))
        // H.264 requires even dimensions; round down to nearest even number.
        cw = cw & ~1
        ch = ch & ~1
        if cw > 0 && ch > 0 {
          videoFilters.append("crop=\(cw):\(ch):\(cx):\(cy)")
        }
      }
    }
    
    guard let outputFile = outputFile else {
      self.onError(message: "Output file path is nil", code: .trimmingFailed)
      return
    }

    if needsReEncode {
      // Preserve source quality by matching the original bitrate. Falls back to 10 Mbps
      // if the track's estimated data rate is unavailable.
      var bitrateStr = "10M"
      if let asset = vc?.asset,
         let videoTrack = asset.tracks(withMediaType: .video).first {
        let bitrate = Int(videoTrack.estimatedDataRate)
        if bitrate > 0 {
          bitrateStr = "\(bitrate)"
        }
      }
      
      // -noautorotate: we handle rotation via explicit transpose filters above,
      // so FFmpeg must not auto-rotate or the output will be double-rotated.
      cmds.append("-noautorotate")
      cmds.append(contentsOf: ["-i", inputFile.path])
      // When enablePreciseTrimming is the only reason for re-encode (no transforms),
      // videoFilters is empty — skip -vf entirely to avoid FFmpeg error on empty filter.
      if !videoFilters.isEmpty {
        cmds.append(contentsOf: ["-vf", videoFilters.joined(separator: ",")])
      }
      // h264_videotoolbox: Apple's hardware H.264 encoder — fast and energy-efficient.
      cmds.append(contentsOf: [
        "-c:v",
        "h264_videotoolbox",
        "-b:v",
        bitrateStr,
        "-c:a",
        "copy",
        "-metadata",
        "creation_time=\(dateTime)",
        outputFile.path
      ])
    } else {
      // Stream copy: no re-encoding, extremely fast but only cuts at keyframes.
      cmds.append(contentsOf: [
        "-i",
        inputFile.path,
        "-c",
        "copy",
        "-metadata",
        "creation_time=\(dateTime)",
        outputFile.path
      ])
    }
    
    print("Command: ", cmds.joined(separator: " "))
    
    let eventPayload: [String: Any] = [
      "message": "Command: \(cmds.joined(separator: " "))"
    ]
    self.emitEventToJS("onLog", eventData: eventPayload)
    
    ffmpegSession = FFmpegKit.execute(withArgumentsAsync: cmds, withCompleteCallback: { session in
      
      let state = session?.getState()
      let returnCode = session?.getReturnCode()
      
      var shouldCloseEditor = false
      
      if ReturnCode.isSuccess(returnCode) {
        let eventPayload: [String: Any] = ["outputPath": outputFile.absoluteString, "startTime": (startTime * 1000).rounded(), "endTime": (endTime * 1000).rounded(), "duration": (videoDuration * 1000).rounded()]
        self.emitEventToJS("onFinishTrimming", eventData: eventPayload)
        
        if (self.saveToPhoto && isVideoType) {
          PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
              self.onError(message: "Permission to access Photo Library is not granted", code: .noPhotoPermission)
              return
            }
            
            PHPhotoLibrary.shared().performChanges({
              let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFile)
              request?.creationDate = Date()
            }) { success, error in
              if success {
                print("Edited video saved to Photo Library successfully.")
                
                if self.removeAfterSavedToPhoto {
                  let _ = VideoTrim.deleteFile(url: outputFile)
                }
              } else {
                self.onError(message: "Failed to save edited video to Photo Library: \(error?.localizedDescription ?? "Unknown error")", code: .failToSaveToPhoto)
                if self.removeAfterFailedToSavePhoto {
                  let _ = VideoTrim.deleteFile(url: outputFile)
                }
              }
            }
          }
        } else if self.openDocumentsOnFinish {
          DispatchQueue.main.async {
            progressAlert.dismiss(animated: true) {
              self.isTrimming = false
              self.saveFileToFilesApp(fileURL: outputFile)
            }
          }
          return
        } else if self.openShareSheetOnFinish {
          DispatchQueue.main.async {
            progressAlert.dismiss(animated: true) {
              self.isTrimming = false
              self.shareFile(fileURL: outputFile)
            }
          }
          return
        }
        
        shouldCloseEditor = self.closeWhenFinish
        
      } else if ReturnCode.isCancel(returnCode) {
        // CANCEL
        self.emitEventToJS("onCancelTrimming", eventData: nil)
      } else {
        // FAILURE
        self.onError(message: "Command failed with state \(String(describing: FFmpegKitConfig.sessionState(toString: state ?? .failed))) and rc \(String(describing: returnCode)).\(String(describing: session?.getFailStackTrace()))", code: .trimmingFailed)
        shouldCloseEditor = self.closeWhenFinish
      }
      
      DispatchQueue.main.async {
        progressAlert.dismiss(animated: true) {
          self.isTrimming = false
          if shouldCloseEditor {
            self.closeEditor()
          }
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
    guard let destPath = URL(string: inputFile) ?? URL(fileURLWithPath: inputFile) as URL? else {
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
    
    // Headless trim: no editor UI, so no transforms (flip/rotate/crop) are possible.
    // The only reason to re-encode here is enablePreciseTrimming for frame-accurate cuts.
    let enablePrecise = config["enablePreciseTrimming"] as? Bool ?? false
    
    if enablePrecise {
      // Match source bitrate to preserve quality; fall back to 10 Mbps.
      var bitrateStr = "10M"
      let asset = AVURLAsset(url: destPath)
      if let videoTrack = asset.tracks(withMediaType: .video).first {
        let bitrate = Int(videoTrack.estimatedDataRate)
        if bitrate > 0 {
          bitrateStr = "\(bitrate)"
        }
      }
      
      // No -noautorotate here: headless trim has no manual rotation filters,
      // so FFmpeg's auto-rotation produces the correct output orientation.
      cmds.append(contentsOf: [
        "-i",
        destPath.path,
        "-c:v",
        "h264_videotoolbox",
        "-b:v",
        bitrateStr,
        "-c:a",
        "copy",
        "-metadata",
        "creation_time=\(dateTime)",
        outputFile.path
      ])
    } else {
      // Stream copy: no re-encoding, extremely fast but only cuts at keyframes.
      cmds.append(contentsOf: [
        "-i",
        destPath.path,
        "-c",
        "copy",
        "-metadata",
        "creation_time=\(dateTime)",
        outputFile.path
      ])
    }
    
    print("Command: ", cmds.joined(separator: " "))
    
    FFmpegKit.execute(withArgumentsAsync: cmds, withCompleteCallback: { session in
      let returnCode = session?.getReturnCode()
      
      if ReturnCode.isSuccess(returnCode) {
        // Handle saveToPhoto functionality
        if let saveToPhoto = config["saveToPhoto"] as? Bool, saveToPhoto {
          print("iOS trim: saveToPhoto is true, attempting to save to photo library")
          // Check if it's a video type
          let isVideoType = (config["type"] as? String ?? "video") == "video"
          
          if isVideoType {
            PHPhotoLibrary.requestAuthorization { status in
              DispatchQueue.main.async {
                if status == .authorized {
                  PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFile)
                  }) { success, error in
                    if success {
                      print("Edited video saved to Photo Library successfully.")
                      
                      // Handle removeAfterSavedToPhoto
                      if let removeAfterSaved = config["removeAfterSavedToPhoto"] as? Bool, removeAfterSaved {
                        let _ = VideoTrim.deleteFile(url: outputFile)
                      }
                      
                      let result = [
                        "success": true,
                        "outputPath": outputFile.absoluteString,
                        "startTime": startTime,
                        "endTime": endTime,
                        "duration": endTime - startTime
                      ] as [String : Any]
                      
                      completion(result)
                    } else {
                      print("Failed to save edited video to Photo Library: \(error?.localizedDescription ?? "Unknown error")")
                      
                      // Handle removeAfterFailedToSavePhoto
                      if let removeAfterFailed = config["removeAfterFailedToSavePhoto"] as? Bool, removeAfterFailed {
                        let _ = VideoTrim.deleteFile(url: outputFile)
                      }
                      
                      let result = [
                        "success": false,
                        "message": "Failed to save edited video to Photo Library: \(error?.localizedDescription ?? "Unknown error")",
                      ] as [String : Any]
                      
                      completion(result)
                    }
                  }
                } else {
                  // Permission denied
                  print("Photo Library access denied")
                  
                  // Handle removeAfterFailedToSavePhoto
                  if let removeAfterFailed = config["removeAfterFailedToSavePhoto"] as? Bool, removeAfterFailed {
                    let _ = VideoTrim.deleteFile(url: outputFile)
                  }
                  
                  let result = [
                    "success": false,
                    "message": "Photo Library access denied",
                  ] as [String : Any]
                  
                  completion(result)
                }
              }
            }
          } else {
            // For audio files, we can't save to photo library, just return success
            let result = [
              "success": true,
              "outputPath": outputFile.absoluteString,
              "startTime": startTime,
              "endTime": endTime,
              "duration": endTime - startTime
            ] as [String : Any]
            
            completion(result)
          }
        } else {
          let result = [
            "success": true,
            "outputPath": outputFile.absoluteString,
            "startTime": startTime,
            "endTime": endTime,
            "duration": endTime - startTime
          ] as [String : Any]
          
          completion(result)
        }
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
          
          if self.removeAfterFailedToShare, let outputFile = self.outputFile {
            let _ = VideoTrim.deleteFile(url: outputFile)
          }
          return
        }
        
        if completed {
          print("User completed the sharing activity")
          if self.removeAfterShared, let outputFile = self.outputFile {
            let _ = VideoTrim.deleteFile(url: outputFile)
          }
        } else {
          print("User cancelled or failed to complete the sharing activity")
          if self.removeAfterFailedToShare, let outputFile = self.outputFile {
            let _ = VideoTrim.deleteFile(url: outputFile)
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
    print("Show editor called with URI: \(uri)")
    
    guard let destPath = URL(string: uri) ?? URL(fileURLWithPath: uri) as URL? else { return }
    print("Destination Path: \(destPath.absoluteString), path: \(destPath.path)")
    
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
        dialogMessage.overrideUserInterfaceStyle = self.isLightTheme ? .light : .dark
        
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
      
      let isVideoType = (config["type"] as? String ?? "video") == "video"
      
      vc.saveBtnClicked = {(selectedRange: CMTimeRange) in
        guard let asset = vc.asset else { return }
        if !self.enableSaveDialog {
          self.trim(viewController: vc,inputFile: destPath, videoDuration: asset.duration.seconds, startTime: selectedRange.start.seconds, endTime: selectedRange.end.seconds, isVideoType: isVideoType)
          return
        }
        
        // Create Alert
        let dialogMessage = UIAlertController(title: self.saveDialogTitle, message: self.saveDialogMessage, preferredStyle: .alert)
        dialogMessage.overrideUserInterfaceStyle = self.isLightTheme ? .light : .dark
        
        // Create OK button with action handler
        let ok = UIAlertAction(title: self.saveDialogConfirmText, style: .default, handler: { (action) -> Void in
          self.trim(viewController: vc,inputFile: destPath, videoDuration: asset.duration.seconds, startTime: selectedRange.start.seconds, endTime: selectedRange.end.seconds, isVideoType: isVideoType)
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
          assetLoader.loadAsset(url: destPath, isVideoType: isVideoType)
        })
      }
    }
  }
  
  // New Arch
  @objc(closeEditor:)
  public func closeEditor(delay: Int = 0) {
    guard let vc = vc else { return }
    let dismissBlock = {
      vc.dismiss(animated: true, completion: {
        self.emitEventToJS("onHide", eventData: nil)
        self.isShowing = false
        self.vc = nil
      })
    }

    if delay > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: dismissBlock)
    } else {
      DispatchQueue.main.async(execute: dismissBlock)
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
    guard let url = URL(string: uri) else { return false }
    let state = deleteFile(url: url)
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
        if fileURL.lastPathComponent.starts(with: FILE_PREFIX) {
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
    guard let fileURL = URL(string: url) ?? URL(fileURLWithPath: url) as URL? else {
      completion(["isValid": false, "fileType": "unknown", "duration": -1])
      return
    }
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
    })
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
      dialogMessage.overrideUserInterfaceStyle = isLightTheme ? .light : .dark
      
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
    
    let duration = loader.asset?.duration.seconds ?? 0
    let eventPayload: [String: Any] = [
      "duration": duration * 1000,
    ]
    self.emitEventToJS("onLoad", eventData: eventPayload)
  }
}


// MARK: DocumentPicker delegate
extension VideoTrim {
  public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    if removeAfterSavedToDocuments, let outputFile = self.outputFile {
      let _ = VideoTrim.deleteFile(url: outputFile)
    }
    closeEditor()
  }
  
  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    if removeAfterFailedToSaveDocuments, let outputFile = self.outputFile {
      let _ = VideoTrim.deleteFile(url: outputFile)
    }
    closeEditor()
  }
}
