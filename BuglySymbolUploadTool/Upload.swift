import Foundation

struct Metadata: Codable {
    
    var jarDirectoryURL: URL?
    var dSYMFileURL: URL?
    var appId: String
    var appKey: String
    var bundleId: String
    var version: String
    private var platform = "IOS"
    
    init(jarDirectoryURL: URL? = nil,
         dSYMFileURL: URL? = nil,
         appId: String = "",
         appKey: String = "",
         bundleId: String = "",
         version: String = "") {
        self.jarDirectoryURL = jarDirectoryURL
        self.dSYMFileURL = dSYMFileURL
        self.appId = appId
        self.appKey = appKey
        self.bundleId = bundleId
        self.version = version
    }
    
    func canUpload() -> Bool {
        var results = [appId, appKey, bundleId, version].map { !$0.isEmpty }
        results += [jarDirectoryURL, dSYMFileURL].map { $0?.isFileURL ?? false }
        return results.dropFirst().reduce(results[0]) { $0 && $1 }
    }
    
    func upload(completionHandler: @escaping (Result<CommandRunner.Output, Error>) -> Void) {
        guard let dSYMFileURL = dSYMFileURL, dSYMFileURL.isFileURL else {
            fatalError("The dSYM file path MUST not be nil.")
        }
        let arguments = [
            "-jar",
            "buglyqq-upload-symbol.jar",
            "-appid",
            appId,
            "-appkey",
            appKey,
            "-bundleid",
            bundleId,
            "-version",
            version,
            "-platform",
            platform,
            "-inputSymbol",
            dSYMFileURL.relativePath
        ]
        
        CommandRunner.asyncExecute(executableURL: URL(fileURLWithPath: "/usr/bin/java"),
                                   arguments: arguments,
                                   currentDirectoryURL: jarDirectoryURL,
                                   completionHandler: completionHandler)
    }
    
}
