import React
import Photos
import AVFoundation
import UIKit
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
  
  private var removeAudio: Bool {
    return editorConfig?["removeAudio"] as? Bool ?? false
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
  
  /// Chains FFmpeg `atempo` filters so each stage stays within 0.5–2.0.
  private func buildAtempoChain(_ speed: Double) -> String {
    var remaining = speed
    var filters: [String] = []
    while remaining < 0.5 {
      filters.append("atempo=0.5")
      remaining /= 0.5
    }
    while remaining > 2.0 {
      filters.append("atempo=2.0")
      remaining /= 2.0
    }
    filters.append("atempo=\(remaining)")
    return filters.joined(separator: ",")
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
    
    // -y overwrites any pre-existing output file without prompting, so FFmpeg never
    // blocks on an interactive "Overwrite? [y/N]" prompt (hardening; also keeps the
    // command symmetric with Android, where -y is required by the encoder fallback chain).
    var cmds = [
      "-y",
      "-ss",
      "\(startTime * 1000)ms",
      "-to",
      "\(endTime * 1000)ms",
    ]
    
    var videoFilters: [String] = []
    let hasUserTransform = vc != nil && (vc!.rotationCount != 0 || vc!.isFlipped)
    let cropNorm = vc?.cropNormalizedRect
    let stripAudio = removeAudio || viewController.isMuted
    let playbackSpeed = viewController.speed
    let needsSpeed = abs(playbackSpeed - 1.0) > 0.0001
    // Re-encode is required when: (1) user applied flip/rotate, (2) user cropped, or
    // (3) enablePreciseTrimming is on, or (4) export speed != 1.0. In those cases, -c copy
    // won't work because we need filters or frame-accurate cut points.
    let needsReEncode = hasUserTransform || cropNorm != nil || enablePreciseTrimming || needsSpeed
    
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
    
    if needsReEncode && needsSpeed {
      videoFilters.append("setpts=\(1.0 / playbackSpeed)*PTS")
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
      ])
      if stripAudio {
        cmds.append("-an")
      } else if needsSpeed {
        cmds.append(contentsOf: ["-af", buildAtempoChain(playbackSpeed), "-c:a", "aac"])
      } else {
        cmds.append(contentsOf: ["-c:a", "copy"])
      }
      cmds.append(contentsOf: [
        "-metadata",
        "creation_time=\(dateTime)",
        outputFile.path
      ])
    } else {
      // Stream copy: no re-encoding, extremely fast but only cuts at keyframes.
      cmds.append(contentsOf: ["-i", inputFile.path])
      if stripAudio {
        cmds.append(contentsOf: ["-c:v", "copy", "-an"])
      } else {
        cmds.append(contentsOf: ["-c", "copy"])
      }
      cmds.append(contentsOf: [
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
        let classified = VideoTrim.classifyFFmpegError(session: session)
        self.onError(message: "Command failed with state \(String(describing: FFmpegKitConfig.sessionState(toString: state ?? .failed))) and rc \(String(describing: returnCode)).\(String(describing: session?.getFailStackTrace()))", code: classified)
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
  @objc(trimWithInputFile:config:completion:)
  public func _trim(inputFile: String, config: NSDictionary, completion: @escaping ([String: Any]) -> Void) {
    let destPath = URL(string: inputFile) ?? URL(fileURLWithPath: inputFile)
    if destPath.path.isEmpty {
      completion([
        "success": false,
        "message": "Invalid input file path",
      ] as [String: Any])
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
    // -y overwrites any pre-existing output file without prompting (hardening).
    var cmds = [
      "-y",
      "-ss",
      "\(startTime)ms",
      "-to",
      "\(endTime)ms",
    ]
    
    // Headless trim: no editor UI, so no transforms (flip/rotate/crop) are possible.
    let enablePrecise = config["enablePreciseTrimming"] as? Bool ?? false
    let stripAudio = config["removeAudio"] as? Bool ?? false
    let speed = config["speed"] as? Double ?? 1.0
    let needsSpeed = abs(speed - 1.0) > 0.0001
    let needsReEncode = enablePrecise || needsSpeed
    
    if needsReEncode {
      // Match source bitrate to preserve quality; fall back to 10 Mbps.
      var bitrateStr = "10M"
      let asset = AVURLAsset(url: destPath)
      if let videoTrack = asset.tracks(withMediaType: .video).first {
        let bitrate = Int(videoTrack.estimatedDataRate)
        if bitrate > 0 {
          bitrateStr = "\(bitrate)"
        }
      }
      
      var videoFilters: [String] = []
      if needsSpeed {
        videoFilters.append("setpts=\(1.0 / speed)*PTS")
      }
      
      // No -noautorotate here: headless trim has no manual rotation filters,
      // so FFmpeg's auto-rotation produces the correct output orientation.
      cmds.append(contentsOf: ["-i", destPath.path])
      if !videoFilters.isEmpty {
        cmds.append(contentsOf: ["-vf", videoFilters.joined(separator: ",")])
      }
      cmds.append(contentsOf: [
        "-c:v",
        "h264_videotoolbox",
        "-b:v",
        bitrateStr,
      ])
      if stripAudio {
        cmds.append("-an")
      } else if needsSpeed {
        cmds.append(contentsOf: ["-af", buildAtempoChain(speed), "-c:a", "aac"])
      } else {
        cmds.append(contentsOf: ["-c:a", "copy"])
      }
      cmds.append(contentsOf: [
        "-metadata",
        "creation_time=\(dateTime)",
        outputFile.path
      ])
    } else {
      // Stream copy: no re-encoding, extremely fast but only cuts at keyframes.
      cmds.append(contentsOf: ["-i", destPath.path])
      if stripAudio {
        cmds.append(contentsOf: ["-c:v", "copy", "-an"])
      } else {
        cmds.append(contentsOf: ["-c", "copy"])
      }
      cmds.append(contentsOf: [
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
        let logs = session?.getAllLogsAsString() ?? ""
        let result = [
          "success": false,
          "message": "Command failed with rc \(String(describing: returnCode)).\(String(describing: session?.getFailStackTrace()))\n\(logs)",
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

  /// Scan an FFmpeg session's log for signatures that indicate the hardware
  /// video encoder (`h264_videotoolbox`) refused to configure on this device.
  /// VideoToolbox failures are extremely rare on supported iOS hardware — Apple
  /// controls the entire stack and regression-tests it — but the classifier
  /// exists for API parity with Android (where the same hardware-encoder bug is
  /// common and reproducible) and to give consumers a more actionable
  /// `errorCode` than the generic `TRIMMING_FAILED` if it ever happens.
  ///
  /// Detected signals:
  ///   - `VTCompressionSession` errors
  ///   - `Error initializing output stream` / `Error while opening encoder`
  ///     combined with a `videotoolbox` mention in the same session log
  static func classifyFFmpegError(session: FFmpegSession?) -> ErrorCode {
    let logs = session?.getAllLogsAsString() ?? ""
    let hardwareEncoderSignals = [
      "VTCompressionSession",
      "Error initializing output stream",
      "Error while opening encoder",
    ]
    let matchedHardwareSignal = hardwareEncoderSignals.contains { logs.contains($0) }
    if matchedHardwareSignal && logs.localizedCaseInsensitiveContains("videotoolbox") {
      return .hardwareEncoderFailed
    }
    return .trimmingFailed
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
  
  // Scans both the documents directory (showEditor/trim outputs) and the caches
  // directory (headless API outputs) for files matching our FILE_PREFIX.
  private static func listFiles() -> [URL] {
    var files: [URL] = []

    let dirs = [
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
      FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!,
    ]

    for dir in dirs {
      do {
        let directoryContents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)

        for fileURL in directoryContents {
          if fileURL.lastPathComponent.starts(with: FILE_PREFIX) {
            files.append(fileURL)
          }
        }
      } catch {
        print("[listFiles] Error when retrieving files in \(dir): \(error)")
      }
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
  
  // MARK: - Headless API: getFrameAt
  // Extracts a single video frame as JPEG/PNG using AVAssetImageGenerator.
  // Output goes to the caches directory (OS-managed, auto-purged under storage pressure).
  @objc
  public static func getFrameAt(_ url: String, options: NSDictionary, completion: @escaping ([String: Any]) -> Void) {
    let destPath = URL(string: url) ?? URL(fileURLWithPath: url)

    let time = options["time"] as? Double ?? 0
    let format = options["format"] as? String ?? "jpeg"
    let qualityNum = options["quality"] as? NSNumber
    let quality = qualityNum?.intValue ?? 80
    let maxWidth = options["maxWidth"] as? Int ?? -1
    let maxHeight = options["maxHeight"] as? Int ?? -1

    DispatchQueue.global(qos: .userInitiated).async {
      let asset = AVURLAsset(url: destPath)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
      generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

      if maxWidth > 0 || maxHeight > 0 {
        let w = maxWidth > 0 ? maxWidth : 0
        let h = maxHeight > 0 ? maxHeight : 0
        generator.maximumSize = CGSize(width: CGFloat(w), height: CGFloat(h))
      } else if let track = asset.tracks(withMediaType: .video).first {
        // AVAssetImageGenerator defaults to a reduced size if maximumSize is not set.
        // Explicitly set it to the video's natural size (accounting for rotation via
        // preferredTransform) to ensure full-resolution frame extraction.
        let size = track.naturalSize.applying(track.preferredTransform)
        generator.maximumSize = CGSize(width: abs(size.width), height: abs(size.height))
      }

      let cmTime = CMTime(value: CMTimeValue(time), timescale: 1000)

      do {
        let cgImage = try generator.copyCGImage(at: cmTime, actualTime: nil)
        let uiImage = UIImage(cgImage: cgImage)

        let timestamp = Int(Date().timeIntervalSince1970)
        let ext = format == "png" ? "png" : "jpg"
        let outputName = "\(FILE_PREFIX)_frame_\(timestamp).\(ext)"
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let outputURL = cacheDirectory.appendingPathComponent(outputName)

        let data: Data?
        if format == "png" {
          data = uiImage.pngData()
        } else {
          data = uiImage.jpegData(compressionQuality: CGFloat(quality) / 100.0)
        }

        guard let imageData = data else {
          completion(["error": "Failed to encode image"])
          return
        }

        try imageData.write(to: outputURL)
        completion(["outputPath": outputURL.absoluteString])
      } catch {
        completion(["error": "Failed to extract frame: \(error.localizedDescription)"])
      }
    }
  }

  // Old Arch
  @objc(getFrameAt:withOptions:withResolver:withRejecter:)
  func getFrameAt(_ url: String, withOptions options: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    VideoTrim.getFrameAt(url, options: options, completion: { payload in
      if let error = payload["error"] as? String {
        reject("ERR_FRAME_EXTRACTION", error, NSError(domain: "", code: 200, userInfo: nil))
      } else {
        resolve(payload)
      }
    })
  }

  // MARK: - Headless API: extractAudio
  // Strips the video track, keeping only audio. Default output is m4a (AAC) because the
  // default FFmpegKit builds do not include libmp3lame, so mp3 encoding would fail.
  @objc
  public static func extractAudio(_ url: String, options: NSDictionary, completion: @escaping ([String: Any]) -> Void) {
    let destPath = URL(string: url) ?? URL(fileURLWithPath: url)

    let outputExt = options["outputExt"] as? String ?? "m4a"
    let timestamp = Int(Date().timeIntervalSince1970)
    let outputName = "\(FILE_PREFIX)_audio_\(timestamp).\(outputExt)"
    let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let outputFile = cacheDirectory.appendingPathComponent(outputName)

    let cmds = ["-i", destPath.path, "-vn", "-y", outputFile.path]
    print("extractAudio command:", cmds.joined(separator: " "))

    FFmpegKit.execute(withArgumentsAsync: cmds, withCompleteCallback: { session in
      let returnCode = session?.getReturnCode()
      if ReturnCode.isSuccess(returnCode) {
        let asset = AVURLAsset(url: outputFile)
        let duration = CMTimeGetSeconds(asset.duration) * 1000
        completion([
          "outputPath": outputFile.absoluteString,
          "duration": duration.rounded()
        ])
      } else {
        let logs = session?.getAllLogsAsString() ?? ""
        completion(["error": "Failed to extract audio: rc \(String(describing: returnCode))\n\(logs)"])
      }
    }, withLogCallback: nil, withStatisticsCallback: nil)
  }

  // Old Arch
  @objc(extractAudio:withOptions:withResolver:withRejecter:)
  func extractAudio(_ url: String, withOptions options: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    VideoTrim.extractAudio(url, options: options, completion: { payload in
      if let error = payload["error"] as? String {
        reject("ERR_EXTRACT_AUDIO", error, NSError(domain: "", code: 200, userInfo: nil))
      } else {
        resolve(payload)
      }
    })
  }

  // MARK: - Headless API: compress
  // Re-encodes video with h264_videotoolbox (hardware) at the requested quality/bitrate.
  // Uses CRF-style -global_quality for quality presets, or explicit -b:v for custom bitrate.
  @objc
  public static func compress(_ url: String, options: NSDictionary, completion: @escaping ([String: Any]) -> Void) {
    let destPath = URL(string: url) ?? URL(fileURLWithPath: url)

    let quality = options["quality"] as? String ?? "medium"
    let bitrate = options["bitrate"] as? Double ?? -1
    let width = options["width"] as? Int ?? -1
    let height = options["height"] as? Int ?? -1
    let frameRate = options["frameRate"] as? Double ?? -1
    let outputExt = options["outputExt"] as? String ?? "mp4"
    let removeAudio = options["removeAudio"] as? Bool ?? false

    let timestamp = Int(Date().timeIntervalSince1970)
    let outputName = "\(FILE_PREFIX)_compressed_\(timestamp).\(outputExt)"
    let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let outputFile = cacheDirectory.appendingPathComponent(outputName)

    var cmds: [String] = ["-i", destPath.path]
    var videoFilters: [String] = []

    if width > 0 && height > 0 {
      videoFilters.append("scale=\(width):\(height)")
    } else if width > 0 {
      videoFilters.append("scale=\(width):-2")
    } else if height > 0 {
      videoFilters.append("scale=-2:\(height)")
    }

    if !videoFilters.isEmpty {
      cmds.append(contentsOf: ["-vf", videoFilters.joined(separator: ",")])
    }

    cmds.append(contentsOf: ["-c:v", "h264_videotoolbox"])

    if bitrate > 0 {
      cmds.append(contentsOf: ["-b:v", "\(Int(bitrate))"])
    } else {
      let crf: String
      switch quality {
      case "low": crf = "28"
      case "high": crf = "18"
      default: crf = "23"
      }
      cmds.append(contentsOf: ["-global_quality", crf])
    }

    if frameRate > 0 {
      cmds.append(contentsOf: ["-r", "\(frameRate)"])
    }

    if removeAudio {
      cmds.append("-an")
    } else {
      cmds.append(contentsOf: ["-c:a", "aac"])
    }

    cmds.append(contentsOf: ["-y", outputFile.path])
    print("compress command:", cmds.joined(separator: " "))

    FFmpegKit.execute(withArgumentsAsync: cmds, withCompleteCallback: { session in
      let returnCode = session?.getReturnCode()
      if ReturnCode.isSuccess(returnCode) {
        completion(["outputPath": outputFile.absoluteString])
      } else {
        let logs = session?.getAllLogsAsString() ?? ""
        completion(["error": "Compression failed: rc \(String(describing: returnCode))\n\(logs)"])
      }
    }, withLogCallback: nil, withStatisticsCallback: nil)
  }

  // Old Arch
  @objc(compress:withOptions:withResolver:withRejecter:)
  func compress(_ url: String, withOptions options: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    VideoTrim.compress(url, options: options, completion: { payload in
      if let error = payload["error"] as? String {
        reject("ERR_COMPRESS", error, NSError(domain: "", code: 200, userInfo: nil))
      } else {
        resolve(payload)
      }
    })
  }

  // MARK: - Headless API: toGif
  // Two-pass GIF conversion: pass 1 generates an optimal palette, pass 2 encodes the GIF
  // using that palette for better color accuracy than single-pass dithering.
  @objc
  public static func toGif(_ url: String, options: NSDictionary, completion: @escaping ([String: Any]) -> Void) {
    let destPath = URL(string: url) ?? URL(fileURLWithPath: url)

    let startTime = options["startTime"] as? Double ?? 0
    let endTime = options["endTime"] as? Double ?? -1
    let fps = options["fps"] as? Int ?? 10
    let width = options["width"] as? Int ?? -1

    let timestamp = Int(Date().timeIntervalSince1970)
    let paletteName = "\(FILE_PREFIX)_palette_\(timestamp).png"
    let outputName = "\(FILE_PREFIX)_gif_\(timestamp).gif"
    let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let paletteFile = cacheDirectory.appendingPathComponent(paletteName)
    let outputFile = cacheDirectory.appendingPathComponent(outputName)

    let scaleExpr = width > 0 ? "\(width):-1" : "-1:-1"
    let filterBase = "fps=\(fps),scale=\(scaleExpr):flags=lanczos"

    var timeArgs: [String] = []
    if startTime > 0 { timeArgs.append(contentsOf: ["-ss", "\(startTime)ms"]) }
    if endTime > 0 { timeArgs.append(contentsOf: ["-to", "\(endTime)ms"]) }

    let pass1 = timeArgs + ["-i", destPath.path, "-vf", "\(filterBase),palettegen", "-y", paletteFile.path]
    print("toGif pass1 command:", pass1.joined(separator: " "))

    FFmpegKit.execute(withArgumentsAsync: pass1, withCompleteCallback: { session in
      guard ReturnCode.isSuccess(session?.getReturnCode()) else {
        let logs = session?.getAllLogsAsString() ?? ""
        completion(["error": "GIF palette generation failed\n\(logs)"])
        return
      }

      let pass2 = timeArgs + [
        "-i", destPath.path,
        "-i", paletteFile.path,
        "-lavfi", "[0:v]\(filterBase)[x];[x][1:v]paletteuse",
        "-y", outputFile.path
      ]
      print("toGif pass2 command:", pass2.joined(separator: " "))

      FFmpegKit.execute(withArgumentsAsync: pass2, withCompleteCallback: { session2 in
        try? FileManager.default.removeItem(at: paletteFile)

        guard ReturnCode.isSuccess(session2?.getReturnCode()) else {
          let logs = session2?.getAllLogsAsString() ?? ""
          completion(["error": "GIF creation failed\n\(logs)"])
          return
        }
        completion(["outputPath": outputFile.absoluteString])
      }, withLogCallback: nil, withStatisticsCallback: nil)
    }, withLogCallback: nil, withStatisticsCallback: nil)
  }

  // Old Arch
  @objc(toGif:withOptions:withResolver:withRejecter:)
  func toGif(_ url: String, withOptions options: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    VideoTrim.toGif(url, options: options, completion: { payload in
      if let error = payload["error"] as? String {
        reject("ERR_GIF", error, NSError(domain: "", code: 200, userInfo: nil))
      } else {
        resolve(payload)
      }
    })
  }

  // MARK: - Headless API: merge
  // Concatenates multiple local video files using FFmpeg's concat *filter* (not demuxer).
  // Each input is normalized to the first clip's resolution via scale+pad+setsar+format
  // before entering the concat, so clips with different dimensions, pixel formats, or SARs
  // merge correctly (mismatched inputs get letterboxed/pillarboxed with black bars).
  //
  // Bitrate: probes all input videos and uses the highest detected bitrate as the target
  // (-b:v) so the output quality matches the best source. Falls back to 10 Mbps.
  //
  // Limitation: only supports local file paths. Remote URLs are not supported because the
  // default FFmpegKit build does not include OpenSSL (--disable-openssl).
  @objc
  public static func merge(_ urls: [String], options: NSDictionary, completion: @escaping ([String: Any]) -> Void) {
    let outputExt = options["outputExt"] as? String ?? "mp4"
    let timestamp = Int(Date().timeIntervalSince1970)
    let outputName = "\(FILE_PREFIX)_merged_\(timestamp).\(outputExt)"
    let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let outputFile = cacheDirectory.appendingPathComponent(outputName)

    guard !urls.isEmpty else {
      completion(["error": "No input URLs"])
      return
    }

    var cmds: [String] = []
    var maxBitrate: Int = 0
    for urlStr in urls {
      let u = URL(string: urlStr) ?? URL(fileURLWithPath: urlStr)
      cmds.append(contentsOf: ["-i", u.path])
      let asset = AVURLAsset(url: u)
      if let track = asset.tracks(withMediaType: .video).first {
        maxBitrate = max(maxBitrate, Int(track.estimatedDataRate))
      }
    }
    let bitrateStr = maxBitrate > 0 ? "\(maxBitrate)" : "10M"

    // Use the first clip's dimensions and frame rate as the target for all inputs.
    let firstURL = URL(string: urls[0]) ?? URL(fileURLWithPath: urls[0])
    let firstAsset = AVURLAsset(url: firstURL)
    var targetW = 1280; var targetH = 720
    var targetFps = 30
    if let track = firstAsset.tracks(withMediaType: .video).first {
      let size = track.naturalSize.applying(track.preferredTransform)
      targetW = Int(abs(size.width))
      targetH = Int(abs(size.height))
      targetFps = min(Int(ceil(track.nominalFrameRate)), 30)
      if targetFps <= 0 { targetFps = 30 }
    }

    // Normalize each input to the same resolution, pixel format, SAR, and frame rate
    // before concat. The fps filter prevents massive frame duplication when inputs have
    // very different frame rates (e.g. 24fps + 60fps would cause thousands of dupes).
    let n = urls.count
    let scaleFilter = "scale=\(targetW):\(targetH):force_original_aspect_ratio=decrease,pad=\(targetW):\(targetH):(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p,fps=\(targetFps)"
    var scaleParts: [String] = []
    for i in 0..<n {
      scaleParts.append("[\(i):v:0]\(scaleFilter)[v\(i)]")
    }
    let concatInputs = (0..<n).map { "[v\($0)][\($0):a:0]" }.joined()
    let filterComplex = scaleParts.joined(separator: ";") + ";" + concatInputs + "concat=n=\(n):v=1:a=1[outv][outa]"

    cmds.append(contentsOf: [
      "-filter_complex", filterComplex,
      "-map", "[outv]", "-map", "[outa]",
      "-c:v", "h264_videotoolbox", "-b:v", bitrateStr,
      "-c:a", "aac",
      "-y", outputFile.path
    ])
    print("merge command:", cmds.joined(separator: " "))

    FFmpegKit.execute(withArgumentsAsync: cmds, withCompleteCallback: { session in
      let returnCode = session?.getReturnCode()
      if ReturnCode.isSuccess(returnCode) {
        let asset = AVURLAsset(url: outputFile)
        let duration = CMTimeGetSeconds(asset.duration) * 1000
        completion([
          "outputPath": outputFile.absoluteString,
          "duration": duration.rounded()
        ])
      } else {
        let logs = session?.getAllLogsAsString() ?? ""
        completion(["error": "Merge failed: rc \(String(describing: returnCode))\n\(logs)"])
      }
    }, withLogCallback: nil, withStatisticsCallback: nil)
  }

  // Old Arch
  @objc(merge:withOptions:withResolver:withRejecter:)
  func merge(_ urls: [String], withOptions options: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    VideoTrim.merge(urls, options: options, completion: { payload in
      if let error = payload["error"] as? String {
        reject("ERR_MERGE", error, NSError(domain: "", code: 200, userInfo: nil))
      } else {
        resolve(payload)
      }
    })
  }

  // MARK: - Utility: saveToPhoto
  // Saves a file to the Photo Library. Detects whether the file is an image or video by
  // extension, then calls the appropriate PHAssetChangeRequest factory method. Using the
  // wrong factory (e.g. creationRequestForAssetFromVideo for a .jpg) causes the Photos
  // app to treat the file as a broken video.

  private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif", "tiff", "tif"]

  @objc
  public static func saveToPhoto(_ filePath: String, completion: @escaping ([String: Any]) -> Void) {
    let fileURL = URL(string: filePath) ?? URL(fileURLWithPath: filePath)

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      completion(["error": "File does not exist at path: \(filePath)"])
      return
    }

    let ext = fileURL.pathExtension.lowercased()
    let isImage = imageExtensions.contains(ext)

    PHPhotoLibrary.requestAuthorization { status in
      guard status == .authorized else {
        completion(["error": "Permission to access Photo Library is not granted"])
        return
      }

      PHPhotoLibrary.shared().performChanges({
        if isImage {
          PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
        } else {
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        }
      }) { success, error in
        if success {
          completion(["success": true])
        } else {
          completion(["error": "Failed to save to Photo Library: \(error?.localizedDescription ?? "Unknown error")"])
        }
      }
    }
  }

  // Old Arch
  @objc(saveToPhoto:withResolver:withRejecter:)
  func saveToPhoto(_ filePath: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    VideoTrim.saveToPhoto(filePath, completion: { payload in
      if let error = payload["error"] as? String {
        reject("ERR_SAVE_TO_PHOTO", error, NSError(domain: "", code: 200, userInfo: nil))
      } else {
        resolve(payload)
      }
    })
  }

  // MARK: - Utility: saveToDocuments
  // Presents UIDocumentPickerViewController in exportToService mode so the user can
  // choose where to save. Uses a standalone DocumentPickerDelegate (retained via
  // objc_setAssociatedObject) that is independent of the editor lifecycle.

  @objc
  public static func saveToDocuments(_ filePath: String, completion: @escaping ([String: Any]) -> Void) {
    let fileURL = URL(string: filePath) ?? URL(fileURLWithPath: filePath)

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      completion(["error": "File does not exist at path: \(filePath)"])
      return
    }

    DispatchQueue.main.async {
      let picker = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
      picker.modalPresentationStyle = .formSheet

      let delegate = DocumentPickerDelegate(completion: completion)
      picker.delegate = delegate
      objc_setAssociatedObject(picker, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

      if let root = RCTPresentedViewController() {
        root.present(picker, animated: true, completion: nil)
      } else {
        completion(["error": "No root view controller available"])
      }
    }
  }

  // Old Arch
  @objc(saveToDocuments:withResolver:withRejecter:)
  func saveToDocuments(_ filePath: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    VideoTrim.saveToDocuments(filePath, completion: { payload in
      if let error = payload["error"] as? String {
        reject("ERR_SAVE_TO_DOCUMENTS", error, NSError(domain: "", code: 200, userInfo: nil))
      } else {
        resolve(payload)
      }
    })
  }

  // MARK: - Utility: share
  // Opens UIActivityViewController with the file URL. The completion handler resolves
  // with success=true if the user completed a share action, false if cancelled.

  @objc
  public static func share(_ filePath: String, completion: @escaping ([String: Any]) -> Void) {
    let fileURL = URL(string: filePath) ?? URL(fileURLWithPath: filePath)

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      completion(["error": "File does not exist at path: \(filePath)"])
      return
    }

    DispatchQueue.main.async {
      let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

      activityVC.completionWithItemsHandler = { _, completed, _, error in
        if let error = error {
          completion(["error": "Sharing error: \(error.localizedDescription)"])
          return
        }
        completion(["success": completed])
      }

      if let root = RCTPresentedViewController() {
        root.present(activityVC, animated: true, completion: nil)
      } else {
        completion(["error": "No root view controller available"])
      }
    }
  }

  // Old Arch
  @objc(share:withResolver:withRejecter:)
  func share(_ filePath: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    VideoTrim.share(filePath, completion: { payload in
      if let error = payload["error"] as? String {
        reject("ERR_SHARE", error, NSError(domain: "", code: 200, userInfo: nil))
      } else {
        resolve(payload)
      }
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

/// Standalone delegate for the `saveToDocuments` utility (not tied to editor lifecycle).
private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
  private let completion: ([String: Any]) -> Void

  init(completion: @escaping ([String: Any]) -> Void) {
    self.completion = completion
    super.init()
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    completion(["success": true])
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    completion(["success": false])
  }
}
