import Foundation

struct CommandRunner {
    
    private init() {}
    
    struct Output {
        let status: Int?
        let message: String?
    }
    
    static func syncExecute(executableURL: URL,
                            arguments: [String]? = nil,
                            currentDirectoryURL: URL? = nil,
                            environment: [String: String]? = nil) throws -> Output {
        
        let pipe = Pipe()
        
        let task = Process()
        task.executableURL = executableURL
        task.arguments = arguments
        task.environment = environment
        task.currentDirectoryURL = currentDirectoryURL
        task.standardOutput = pipe
        try task.run()
        task.waitUntilExit()
        
        let data = try pipe.fileHandleForReading.readToEnd()
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        let status = Int(task.terminationStatus)
        
        return Output(status: status, message: message)
    }
    
    static func asyncExecute(executableURL: URL,
                             arguments: [String]? = nil,
                             currentDirectoryURL: URL? = nil,
                             environment: [String: String]? = nil,
                             completionHandler: @escaping (Result<Output, Error>) -> Void) {
        func _syncExecute(callbackQueue: DispatchQueue?) {
            do {
                let pipe = Pipe()
                pipe.fileHandleForReading.readabilityHandler = { pipe in
                    let data = pipe.availableData
                    guard !data.isEmpty else { return }
                    let message = String(data: data, encoding: .utf8)
                    let output = Output(status: nil, message: message)
                    if let queue = callbackQueue {
                        queue.async { completionHandler(.success(output)) }
                    } else {
                        completionHandler(.success(output))
                    }
                }
                
                let task = Process()
                task.executableURL = executableURL
                task.arguments = arguments
                task.environment = environment
                task.currentDirectoryURL = currentDirectoryURL
                task.standardOutput = pipe
                
                try task.run()
                task.waitUntilExit()
                task.terminationHandler = { process in
                    let status = Int(task.terminationStatus)
                    let output = Output(status: status, message: nil)
                    guard !process.isRunning else { return }
                    pipe.fileHandleForReading.readabilityHandler = nil
                    if let queue = callbackQueue {
                        queue.async { completionHandler(.success(output)) }
                    } else {
                        completionHandler(.success(output))
                    }
                }
            } catch {
                completionHandler(.failure(error))
            }
        }
        DispatchQueue.global().async {
            _syncExecute(callbackQueue: .main)
        }
    }
    
}
