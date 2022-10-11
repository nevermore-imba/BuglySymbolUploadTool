import Cocoa

// https://blog.csdn.net/yueyansheng2/article/details/79341324
class TextField: NSTextField {

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let charactersIgnoringModifiers = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }
        switch charactersIgnoringModifiers {
        case "v":
            return NSApp.sendAction(#selector(NSText.paste(_:)), to: window?.firstResponder, from: self)
        case "c":
            return NSApp.sendAction(#selector(NSText.copy(_:)), to: window?.firstResponder, from: self)
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
    
}
