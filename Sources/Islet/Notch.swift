import AppKit
import SwiftUI

/// Shared state: the current subtitle and display settings.
final class SubtitleModel: ObservableObject {
    @Published var text = ""
    @Published var expanded = false
    @Published var fontSize: CGFloat = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat ?? 17 {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    @Published var autoHide: Bool = UserDefaults.standard.object(forKey: "autoHide") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoHide, forKey: "autoHide"); scheduleHide() }
    }
    var hideAfter: TimeInterval = 7

    private var hideWork: DispatchWorkItem?

    func show(_ newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        text = trimmed
        expanded = !trimmed.isEmpty
        scheduleHide()
    }

    func clear() { show("") }

    private func scheduleHide() {
        hideWork?.cancel()
        guard autoHide, expanded else { return }
        let work = DispatchWorkItem { [weak self] in self?.expanded = false }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + hideAfter, execute: work)
    }
}

/// Geometry of the hardware notch on a given screen (or a fake one on screens without it).
struct NotchGeometry {
    var size: CGSize
    var hasNotch: Bool

    init(screen: NSScreen) {
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            size = CGSize(width: screen.frame.width - left.width - right.width, height: top)
            hasNotch = true
        } else {
            size = CGSize(width: 190, height: NSStatusBar.system.thickness)
            hasNotch = false
        }
    }
}

/// Black notch-like shape: flat top that blends into the bezel, rounded bottom corners
/// and small outward curves at the top so it looks like it grows out of the notch.
struct NotchShape: Shape {
    var bottomRadius: CGFloat
    var topRadius: CGFloat = 8

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let t = topRadius
        let b = min(bottomRadius, rect.height / 2, (rect.width - 2 * t) / 2)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY + t),
                       control: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t + b, y: rect.maxY),
                       control: CGPoint(x: rect.minX + t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - t, y: rect.maxY - b),
                       control: CGPoint(x: rect.maxX - t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct NotchView: View {
    @ObservedObject var model: SubtitleModel
    let notch: NotchGeometry
    let expandedWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var content: some View {
        // The shape is 2*topRadius wider than its visible body because of the top flares.
        let flare: CGFloat = 8
        return ZStack(alignment: .top) {
            if model.expanded {
                Text(model.text)
                    .font(.system(size: model.fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity)
                    .padding(.top, notch.size.height + 6)
                    .padding(.horizontal, 22 + flare)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
        }
        .frame(width: model.expanded ? expandedWidth : notch.size.width + 2 * flare,
               height: model.expanded ? nil : notch.size.height,
               alignment: .top)
        .background(
            NotchShape(bottomRadius: model.expanded ? 22 : 10, topRadius: flare)
                .fill(Color.black)
        )
        .opacity(model.expanded || notch.hasNotch ? 1 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: model.expanded)
        .animation(.easeOut(duration: 0.15), value: model.text)
    }
}

/// Borderless, click-through panel that sits on top of the menu bar over the notch.
final class NotchPanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
        isMovable = false
        // Keep the subtitles out of screenshots, recordings and screen sharing.
        sharingType = UserDefaults.standard.object(forKey: "hideFromCapture") as? Bool ?? true ? .none : .readOnly
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class NotchController {
    private let panel = NotchPanel()
    private let model: SubtitleModel

    init(model: SubtitleModel) {
        self.model = model
        layout()
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.layout() }
    }

    var hiddenFromCapture: Bool {
        get { panel.sharingType == .none }
        set {
            panel.sharingType = newValue ? .none : .readOnly
            UserDefaults.standard.set(newValue, forKey: "hideFromCapture")
        }
    }

    private func targetScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    func layout() {
        guard let screen = targetScreen() else { return }
        let notch = NotchGeometry(screen: screen)
        let expandedWidth = min(max(screen.frame.width * 0.42, 420), 680)
        let size = CGSize(width: expandedWidth + 40, height: 260)
        let origin = CGPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        let host = NSHostingView(rootView: NotchView(model: model, notch: notch, expandedWidth: expandedWidth))
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear
        panel.contentView = host
    }
}
