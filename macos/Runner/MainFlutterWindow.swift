import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // 목업: iPhone 비율 창 (390 x 844)
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 390, height: 844)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
