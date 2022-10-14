import Foundation

struct Metadata: Codable {
    
    let jarDirectoryURL: URL?
    var dSYMFileURL: URL?
    var appId: String
    var appKey: String
    var bundleId: String
    var version: String
    private var platform = "IOS"
    
    init(dSYMFileURL: URL? = nil,
         appId: String = "",
         appKey: String = "",
         bundleId: String = "",
         version: String = "") {
        let jarDirectoryPath = Bundle.main.infoDictionary?["BUGLY_QQ_UPLOAD_SYMBOL_PATH"] as? String
        self.jarDirectoryURL = jarDirectoryPath.flatMap { URL(fileURLWithPath: $0, isDirectory: true) }
        self.dSYMFileURL = dSYMFileURL
        self.appId = appId
        self.appKey = appKey
        self.bundleId = bundleId
        self.version = version
    }
    
    func upload(completionHandler: @escaping (Result<CommandRunner.Output, Error>) -> Void) {
        guard let jarDirectoryURL = jarDirectoryURL, jarDirectoryURL.isFileURL, jarDirectoryURL.lastPathComponent == "buglyqq-upload-symbol" else {
            completionHandler(.failure(BSUTError.jarDirectoryPathMissing))
            return
        }
        guard !appId.isEmpty else {
            completionHandler(.failure(BSUTError.invalidParameters("App ID for Bugly")))
            return
        }
        guard !appKey.isEmpty else {
            completionHandler(.failure(BSUTError.invalidParameters("App Key for Bugly")))
            return
        }
        guard !bundleId.isEmpty else {
            completionHandler(.failure(BSUTError.invalidParameters("Bundle ID for your project")))
            return
        }
        guard !version.isEmpty else {
            completionHandler(.failure(BSUTError.invalidParameters("Crash version for your project")))
            return
        }
        guard let dSYMFileURL = dSYMFileURL, dSYMFileURL.isFileURL, dSYMFileURL.pathExtension == "dSYM" else {
            completionHandler(.failure(BSUTError.dSYMFilePathMissing))
            return
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

extension Metadata {
    
    private
    static let metadataStorageKey = "com.axe.metadata-storage-key"
    
    func write() throws {
        let data = try JSONEncoder().encode(self)
        UserDefaults.standard.set(data, forKey: Self.metadataStorageKey)
    }
    
    static func read() throws -> Metadata? {
        guard let data = UserDefaults.standard.object(forKey: Self.metadataStorageKey) as? Data else {
            return nil
        }
        return try JSONDecoder().decode(Metadata.self, from: data)
    }
}
