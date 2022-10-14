import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet private weak var appIdTextField: TextField!
    @IBOutlet private weak var appKeyTextField: TextField!
    @IBOutlet private weak var bundleIdTextField: TextField!
    @IBOutlet private weak var versionTextField: TextField!
    @IBOutlet private weak var dSYMFilePathTextField: TextField!
    
    @IBOutlet private weak var uploadButton: NSButton!
    @IBOutlet private weak var logOutputView: NSTextView!
    
    private var metadata = Metadata()
    
    private lazy var textFields = [
        appIdTextField,
        appKeyTextField,
        bundleIdTextField,
        versionTextField,
        dSYMFilePathTextField
    ].compactMap { $0 }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textFields.forEach { $0.delegate = self }
        
        if let metadata = try? Metadata.read() {
            appIdTextField.stringValue = metadata.appId
            appKeyTextField.stringValue = metadata.appKey
            bundleIdTextField.stringValue = metadata.bundleId
            versionTextField.stringValue = metadata.version
            if let dSYMFileURL = metadata.dSYMFileURL {
                dSYMFilePathTextField.stringValue = dSYMFileURL.relativePath
            }
            textFields.forEach(reloadMetadata(textField:))
        }
    }
    
    // MARK: Actions
    
    @IBAction func dSYMFileSelectButtonClicked(_ sender: NSButton) {
        pickerDSYMFile { [weak self] path in
            guard let self = self else { return }
            let dSYMFileURL = path.flatMap { URL(fileURLWithPath: $0, isDirectory: false) }
            self.metadata.dSYMFileURL = dSYMFileURL
            self.dSYMFilePathTextField.stringValue = dSYMFileURL?.relativePath ?? ""
        }
    }
    
    @IBAction func uploadButtonClicked(_ sender: NSButton) {
        textFields.forEach(reloadMetadata(textField:))
        do {
            try metadata.write()
            upload()
        } catch {
            showErrorToast(error)
        }
    }
    
}

// MARK: NSTextFieldDelegate

extension ViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ noti: Notification) {
        guard let textField = noti.object as? TextField else {
            fatalError()
        }
        reloadMetadata(textField: textField)
    }
    
    func controlTextDidEndEditing(_ noti: Notification) {
        controlTextDidChange(noti)
    }
    
}

// MARK: dSYM File

private extension ViewController {
    
    func pickerDSYMFile(_ completionHandler: @escaping (String?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowsOtherFileTypes = false
        openPanel.allowedFileTypes = ["dSYM"]
        openPanel.beginSheetModal(for: NSApplication.shared.windows[0]) { modalResponse in
            switch modalResponse {
            case .OK:
                let path = openPanel.urls[0].path
                completionHandler(path)
            default:
                completionHandler(nil)
            }
        }
    }
    
}

// MARK: Helper

private extension ViewController {
    
    func upload() {
        uploadButton.isEnabled = false
        metadata.upload { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let output):
                if let message = output.message {
                    self.displayLog(message, isWarning: false)
                } else if let status = output.status {
                    self.deleteZipFileInBackground()
                    self.uploadButton.isEnabled = true
                    if status != 0 {
                        self.showToast("Upload failed.")
                    } else {
                        self.showToast("Upload succeeded.")
                    }
                } else {
                    fatalError()
                }
            case .failure(let error):
                self.uploadButton.isEnabled = true
                self.showErrorToast(error)
                self.displayLog("*** Error: " + String(describing: error) + "\n", isWarning: true)
            }
        }
    }
    
    func deleteZipFileInBackground() {
        guard let dSYMFileURL = metadata.dSYMFileURL else { return }
        DispatchQueue.global(qos: .background).async {
            let zipURL = dSYMFileURL.appendingPathExtension("zip")
            let fileManager = FileManager.default
            let exists = fileManager.fileExists(atPath: zipURL.relativePath)
            guard exists else { return }
            do {
                try fileManager.removeItem(at: zipURL)
            } catch {
                debugPrint(error)
            }
        }
    }
    
    func reloadMetadata(textField: TextField) {
        let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch textField {
        case appIdTextField:
            metadata.appId = text
        case appKeyTextField:
            metadata.appKey = text
        case bundleIdTextField:
            metadata.bundleId = text
        case versionTextField:
            metadata.version = text
        case dSYMFilePathTextField:
            let dSYMFileURL = URL(fileURLWithPath: text, isDirectory: false)
            metadata.dSYMFileURL = dSYMFileURL.isFileURL ? dSYMFileURL : nil
        default:
            fatalError()
        }
    }
    
    func showToast(_ message: String) {
        let execute = {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = message
            alert.beginSheetModal(for: self.view.window!)
        }
        DispatchQueue.main.async(execute: execute)
    }
    
    func showErrorToast(_ error: Error) {
        let execute = {
            let alert = NSAlert(error: error)
            alert.beginSheetModal(for: self.view.window!)
        }
        DispatchQueue.main.async(execute: execute)
    }
    
    func displayLog(_ message: String, isWarning: Bool) {
        let execute = {
            let textColor: NSColor = isWarning ? .systemRed : .labelColor
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.preferredFont(forTextStyle: .body),
                .foregroundColor: textColor
            ]
            let attributeText = NSAttributedString(string: message, attributes: attributes)
            self.logOutputView.textStorage?.append(attributeText)
            if !message.hasSuffix(".") {
                self.logOutputView.textStorage?.mutableString.append("\n")
            }
            let visibleRange = NSRange(location: self.logOutputView.textStorage!.length - 1, length: 1)
            self.logOutputView.scrollRangeToVisible(visibleRange)
        }
        DispatchQueue.main.async(execute: execute)
    }
}
