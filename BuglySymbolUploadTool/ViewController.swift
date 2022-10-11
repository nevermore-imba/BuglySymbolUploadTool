import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet private weak var appIdTextField: TextField!
    @IBOutlet private weak var appKeyTextField: TextField!
    @IBOutlet private weak var bundleIdTextField: TextField!
    @IBOutlet private weak var versionTextField: TextField!
    @IBOutlet private weak var dSYMPopUpButton: NSPopUpButton!
    @IBOutlet private weak var uploadButton: NSButton!
    @IBOutlet private weak var logOutputView: NSTextView!
    
    private var metadata = Metadata()
    
    private lazy var textFields = [
        appIdTextField,
        appKeyTextField,
        bundleIdTextField,
        versionTextField
    ].compactMap { $0 }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                                
        textFields.forEach { $0.delegate = self }
        uploadButton.isEnabled = false

        if let jarDirectoryPath = Bundle.main.infoDictionary?["BUGLY_QQ_UPLOAD_SYMBOL_PATH"] as? String {
            metadata.jarDirectoryURL = URL(fileURLWithPath: jarDirectoryPath, isDirectory: true)
        } else {
            showToast("jarDirectoryURL MUST not be nil.")
        }

        if let metadata = try? readMetadata() {
            appIdTextField.stringValue = metadata.appId
            appKeyTextField.stringValue = metadata.appKey
            bundleIdTextField.stringValue = metadata.bundleId
            versionTextField.stringValue = metadata.version
            textFields.forEach(reloadMetadata(textField:))
        }
    }
    
    @IBAction func selectDSYMPopUpButtonClicked(_ sender: NSPopUpButton) {
        textFields.forEach { $0.window?.makeFirstResponder(nil) }
        
        let indexOfSelectedItem = sender.indexOfSelectedItem
        switch indexOfSelectedItem {
        case 0:
            pickerDSYMFile { [weak self] path in
                guard let self = self else { return }
                let dSYMFileURL = path.flatMap { URL(fileURLWithPath: $0, isDirectory: false) }
                self.metadata.dSYMFileURL = dSYMFileURL
                self.reloadDSYMPopUpButton()
                self.reloadUploadButton()
            }
        case 1:
            reloadDSYMPopUpButton()
            reloadUploadButton()
        default:
            let message = "请选择 dSYM 文件"
            displayLog(message, isWarning: true)
        }
    }
    
    // MARK: Actions
    
    @IBAction func uploadButtonClicked(_ sender: NSButton) {
        textFields.forEach(reloadMetadata(textField:))
        
        guard metadata.canUpload() else {
            let checkTexts = [
                metadata.appId,
                metadata.appKey,
                metadata.bundleId,
                metadata.version,
                metadata.dSYMFileURL?.absoluteString ?? ""
            ]
            let invalidIndex = checkTexts
                .firstIndex { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            switch invalidIndex {
            case 0:
                showToast("请输入有效的 Bugly App ID")
            case 1:
                showToast("请输入有效的 Bugly App Key")
            case 2:
                showToast("请输入有效的 Bundle ID")
            case 3:
                showToast("请输入有效的应用版本")
            case 4:
                showToast("请选择有效的符号表文件(.dSYM)")
            default:
                showToast("参数有误，请检查")
            }
            return
        }
        
        try? writeMetadata()
                
        upload()
    }
    
}

// MARK: NSTextFieldDelegate

extension ViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ noti: Notification) {
        guard let textField = noti.object as? TextField else {
            fatalError()
        }
        reloadMetadata(textField: textField)
        reloadUploadButton()
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

// MARK: Caches

private extension ViewController {
    
    static let metadataStorageKey = "com.axe.metadata-storage-key"
    
    func writeMetadata() throws {
        let data = try JSONEncoder().encode(metadata)
        UserDefaults.standard.set(data, forKey: Self.metadataStorageKey)
    }
    
    func readMetadata() throws -> Metadata? {
        guard let data = UserDefaults.standard.object(forKey: Self.metadataStorageKey) as? Data else {
            return nil
        }
        return try JSONDecoder().decode(Metadata.self, from: data)
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
                    DispatchQueue.main.async {
                        self.displayLog(message, isWarning: false)
                    }
                } else if let status = output.status {
                    self.uploadButton.isEnabled = true
                    self.deleteZipFileInBackground()
                    print(status == 0 ? "Task success" : "Task failed")
                } else {
                    fatalError()
                }
            case .failure(let error):
                let errmsg = error.localizedDescription
                DispatchQueue.main.async {
                    self.uploadButton.isEnabled = true
                    self.showToast(errmsg)
                    self.displayLog(errmsg, isWarning: true)
                }
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
                print(error)
            }
        }
    }
    
    func reloadDSYMPopUpButton() {
        dSYMPopUpButton.removeAllItems()
        dSYMPopUpButton.addItem(withTitle: "选择 dSYM 文件")
        if let dSYMFileURL = metadata.dSYMFileURL, dSYMFileURL.isFileURL {
            dSYMPopUpButton.addItem(withTitle: dSYMFileURL.lastPathComponent)
            let selectIndex = dSYMPopUpButton.itemTitles.firstIndex(of: dSYMFileURL.lastPathComponent) ?? 0
            if selectIndex != dSYMPopUpButton.indexOfSelectedItem {
                dSYMPopUpButton.selectItem(at: selectIndex)
            }
        }
    }
    
    func reloadUploadButton() {
        uploadButton.isEnabled = metadata.canUpload()
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
    
    private func displayLog(_ message: String, isWarning: Bool) {
        let execute = {
            var attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12.0)]
            if isWarning {
                attributes[.foregroundColor] = NSColor.red
            } else {
                attributes[.foregroundColor] = NSColor.black
            }
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
