import NitroModules
import ffmpegkit
import Photos

class VideoTrim: HybridVideoTrimSpec {
    
    private let impl = VideoTrimImpl()
    
    public func showEditor(
        filePath: String,
        config: EditorConfig,
        onEvent: @escaping (_ eventName: String, _ payload: Dictionary<String, String>) -> Void
    ) throws {
        impl.showEditor(uri: filePath, editorConfig: config, onEvent: onEvent)
    }
    
    func listFiles() throws -> Promise<[String]> {
        return Promise.async {
            // This runs on a separate Thread, and can use `await` syntax!
            let files = self.impl.listFiles().map { $0.absoluteString }
            return files
        }
    }
    
    public func cleanFiles() throws -> Promise<Double> {
        return Promise.async {
            // This runs on a separate Thread, and can use `await` syntax!
            let files = self.impl.listFiles()
            var successCount = 0
            for file in files {
                let state = self.impl.deleteFile(url: file)
                
                if state == 0 {
                    successCount += 1
                }
            }
            
            return Double(successCount)
        }
    }
    
    public func deleteFile(filePath: String) throws -> Promise<Bool> {
        return Promise.async {
            // This runs on a separate Thread, and can use `await` syntax!
            let state = self.impl.deleteFile(url: URL(string: filePath)!)
            return state == 0
        }
    }
    
    public func closeEditor(onComplete: @escaping () -> Void) throws {
        impl.closeEditor(onComplete)
    }
    
    public func isValidFile(url: String) throws -> Promise<FileValidationResult> {
        return Promise.async {
            // This runs on a separate Thread, and can use```` `await` syntax!
            return await self.impl.isValidFile(uri: url)
        }
    }
}
