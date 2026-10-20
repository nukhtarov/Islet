import AppKit
import CoreImage.CIFilterBuiltins

let serverPort: UInt16 = 8765

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = SubtitleModel()
    let server = HTTPServer(port: serverPort)
    var notch: NotchController?
    var statusItem: NSStatusItem!

    var phoneURL: String { "http://\(localIPAddress() ?? "localhost"):\(serverPort)" }

    func applicationDidFinishLaunching(_ note: Notification) {
        notch = NotchController(model: model)
        server.onText = { [weak self] text in self?.model.show(text) }
        do { try server.start() } catch {
            alert("Не удалось запустить сервер на порту \(serverPort)", error.localizedDescription)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "captions.bubble", accessibilityDescription: "Islet")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.isVisible = !UserDefaults.standard.bool(forKey: "hideStatusIcon")
        applyCaptureHiding()

        model.show("Islet запущен — открой \(phoneURL) на телефоне")
    }

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let url = NSMenuItem(title: phoneURL, action: #selector(copyURL), keyEquivalent: "")
        url.toolTip = "Нажми, чтобы скопировать"
        menu.addItem(url)
        menu.addItem(item("Показать QR-код для телефона…", #selector(showQR), "q"))
        menu.addItem(.separator())
        menu.addItem(item("Тестовый текст", #selector(test), "t"))
        menu.addItem(item("Скрыть текст", #selector(clear), "k"))
        let auto = item("Автоскрытие через \(Int(model.hideAfter)) с", #selector(toggleAutoHide), "")
        auto.state = model.autoHide ? .on : .off
        menu.addItem(auto)
        let hide = item("Скрывать при демонстрации экрана", #selector(toggleHideFromCapture), "")
        hide.state = notch?.hiddenFromCapture == true ? .on : .off
        menu.addItem(hide)
        menu.addItem(item("Убрать иконку из строки меню", #selector(hideStatusIcon), ""))

        let sizes = NSMenu()
        for size in [14, 17, 20, 24] {
            let s = item("\(size) pt", #selector(setFont(_:)), "")
            s.tag = size
            s.state = Int(model.fontSize) == size ? .on : .off
            sizes.addItem(s)
        }
        let sizeItem = NSMenuItem(title: "Размер шрифта", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizes
        menu.addItem(sizeItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(phoneURL, forType: .string)
    }

    @objc func test() { model.show("Привет! Это субтитры с телефона в вырезе MacBook ✨") }
    @objc func clear() { model.clear() }
    @objc func toggleAutoHide() { model.autoHide.toggle() }
    @objc func toggleHideFromCapture() {
        notch?.hiddenFromCapture.toggle()
        applyCaptureHiding()
    }

    /// The menu bar icon follows the same "hide from capture" setting as the notch.
    private func applyCaptureHiding() {
        statusItem.button?.window?.sharingType = notch?.hiddenFromCapture == true ? .none : .readOnly
    }

    @objc func hideStatusIcon() {
        let a = NSAlert()
        a.messageText = "Убрать иконку?"
        a.informativeText = "Islet продолжит работать. Чтобы вернуть иконку, снова открой Islet.app."
        a.addButton(withTitle: "Убрать")
        a.addButton(withTitle: "Отмена")
        guard run(a) == .alertFirstButtonReturn else { return }
        statusItem.isVisible = false
        UserDefaults.standard.set(true, forKey: "hideStatusIcon")
    }

    /// Opening Islet.app again while it runs brings the icon back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        statusItem.isVisible = true
        UserDefaults.standard.set(false, forKey: "hideStatusIcon")
        applyCaptureHiding()
        return false
    }

    /// Runs an alert, keeping it out of screen capture when hiding is on.
    @discardableResult
    private func run(_ a: NSAlert) -> NSApplication.ModalResponse {
        if notch?.hiddenFromCapture == true { a.window.sharingType = .none }
        NSApp.activate(ignoringOtherApps: true)
        return a.runModal()
    }
    @objc func setFont(_ sender: NSMenuItem) { model.fontSize = CGFloat(sender.tag) }

    @objc func showQR() {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(phoneURL.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else { return }
        let rep = NSCIImageRep(ciImage: output)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)

        let view = NSImageView(frame: NSRect(x: 0, y: 0, width: 260, height: 260))
        view.image = image
        view.imageScaling = .scaleProportionallyUpOrDown
        let a = NSAlert()
        a.messageText = "Наведи камеру телефона"
        a.informativeText = "\(phoneURL)\n\nТелефон и Mac должны быть в одной Wi-Fi сети."
        a.accessoryView = view
        run(a)
    }

    private func alert(_ title: String, _ text: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        run(a)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) { buildMenu(menu) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
