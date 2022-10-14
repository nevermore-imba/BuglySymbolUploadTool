import Cocoa

// https://blog.csdn.net/yueyansheng2/article/details/79341324
class TextField: NSTextField {

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let action: Selector?
        switch event.charactersIgnoringModifiers {
        case "v":
            action = #selector(NSText.paste(_:))
        case "c":
            action = #selector(NSText.copy(_:))
        default:
            action = nil
        }
        if let action = action {
            return NSApp.sendAction(action, to: window?.firstResponder, from: self)
        } else {
            return super.performKeyEquivalent(with: event)
        }
    }
    
}
