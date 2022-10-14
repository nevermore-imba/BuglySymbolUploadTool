import Foundation

enum BSUTError: LocalizedError, CustomStringConvertible {
    case jarDirectoryPathMissing
    case dSYMFilePathMissing
    case invalidParameters(String)
    
    var description: String {
        switch self {
        case .jarDirectoryPathMissing:
            return "Not found 'buglyqq-upload-symbol' tool files."
        case .dSYMFilePathMissing:
            return "Not found dSYM file."
        case .invalidParameters(let key):
            return "Invalid input key '\(key)'."
        }
    }
    
    var errorDescription: String? { description }
    
    var recoverySuggestion: String? {
        switch self {
        case .jarDirectoryPathMissing:
            return """
            The first step is to check whether this project info.plist file has a 'BUGLY_QQ_UPLOAD_SYMBOL_PATH' key with the value of '$(SRCROOT)/buglyqq-upload-symbol'. If not, manually add it to info.plist.\n
            Next, check whether the project root directory exists the 'buglyqq-upload-symbol' folder, which is the Bugly official tool kit for uploading symbol tables.
            If it does not exist please go ahead and download it yourself and unzip it in the root directory of this project.
            Download link: https://bugly.qq.com/v2/downloads.
            """
        case .dSYMFilePathMissing:
            return """
            Please select a correct dSYM file, it should be a suffix called 'dSYM' file.\n
            More reference: https://bugly.qq.com/docs/user-guide/symbol-configuration-ios/?v=20221012200308.
            """
        case .invalidParameters(_):
            return nil
        }
    }
    
}
