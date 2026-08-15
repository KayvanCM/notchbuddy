import Cocoa
import SwiftUI

// MARK: - Pixel Crab mascot
// 16×8 pixel grid, converted from Claude Code's official SVG logo (#D97757).
// Wide body up top with two eye cutouts, arms extending out to the sides,
// waist, and four legs hanging down.

let PIXEL_W: CGFloat = 2
let PIXEL_H: CGFloat = 3
let CRAB_CORAL = Color(red: 217/255, green: 119/255, blue: 87/255)

private let CRAB_BODY: [(Int, Int)] = [
    // Row 0 — body top
    (2,0),(3,0),(4,0),(5,0),(6,0),(7,0),(8,0),(9,0),(10,0),(11,0),(12,0),(13,0),
    // Row 1 — body
    (2,1),(3,1),(4,1),(5,1),(6,1),(7,1),(8,1),(9,1),(10,1),(11,1),(12,1),(13,1),
    // Row 2 — eye row (eyes at cols 4 and 11 are cutouts)
    (2,2),(3,2),(5,2),(6,2),(7,2),(8,2),(9,2),(10,2),(12,2),(13,2),
    // Row 3 — arms extend full width
    (0,3),(1,3),(2,3),(3,3),(4,3),(5,3),(6,3),(7,3),(8,3),(9,3),(10,3),(11,3),(12,3),(13,3),(14,3),(15,3),
    // Row 4 — arms
    (0,4),(1,4),(2,4),(3,4),(4,4),(5,4),(6,4),(7,4),(8,4),(9,4),(10,4),(11,4),(12,4),(13,4),(14,4),(15,4),
    // Row 5 — waist (arms ended, body back to 12 wide)
    (2,5),(3,5),(4,5),(5,5),(6,5),(7,5),(8,5),(9,5),(10,5),(11,5),(12,5),(13,5),
    // Row 6 — 4 legs poking down, big empty middle
    (3,6),(5,6),(10,6),(12,6),
    // Row 7 — leg tips
    (3,7),(5,7),(10,7),(12,7),
]
private let CRAB_EYES: [(Int, Int)] = [(4, 2), (4, 3), (11, 2), (11, 3)]

struct PixelCrab: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 16 * PIXEL_W, height: 8 * PIXEL_H)
            ForEach(0..<CRAB_BODY.count, id: \.self) { i in
                let (x, y) = CRAB_BODY[i]
                Rectangle()
                    .fill(CRAB_CORAL)
                    .frame(width: PIXEL_W, height: PIXEL_H)
                    .offset(x: CGFloat(x) * PIXEL_W, y: CGFloat(y) * PIXEL_H)
            }
            ForEach(0..<CRAB_EYES.count, id: \.self) { i in
                let (x, y) = CRAB_EYES[i]
                Rectangle()
                    .fill(Color.black)
                    .frame(width: PIXEL_W, height: PIXEL_H)
                    .offset(x: CGFloat(x) * PIXEL_W, y: CGFloat(y) * PIXEL_H)
            }
        }
        .frame(width: 16 * PIXEL_W, height: 8 * PIXEL_H, alignment: .topLeading)
        .drawingGroup()
    }
}

// MARK: - State controller

class StateController: ObservableObject {
    @Published var state: String = "idle"
    private var resetTimer: Timer?

    func set(_ raw: String) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ["idle", "thinking", "waiting", "done", "error"].contains(s) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            state = s
        }
        resetTimer?.invalidate()
        if s == "done" || s == "error" {
            resetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    self?.state = "idle"
                }
            }
        }
    }
}

// MARK: - Thinking dots

struct ThinkingDots: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 5, height: 5)
                    .scaleEffect(pulse ? 1.0 : 0.65)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: pulse
                    )
            }
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Pixel thinking dots (matches the crab's pixel scale)

struct PixelPulsingDot: View {
    let delay: Double
    @State private var on = false
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: PIXEL_W, height: PIXEL_W)
            .opacity(on ? 1.0 : 0.25)
            .animation(
                .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: on
            )
            .onAppear { on = true }
    }
}

struct PixelThinkingDots: View {
    var body: some View {
        HStack(spacing: 2) {
            PixelPulsingDot(delay: 0.00)
            PixelPulsingDot(delay: 0.18)
            PixelPulsingDot(delay: 0.36)
        }
    }
}

// MARK: - Notch view

// MacBook Pro physical notch is ~32pt tall from the top of the screen.
// Content needs to sit BELOW this line to be visible around the physical cutout.
let NOTCH_HEIGHT: CGFloat = 32

struct NotchView: View {
    @ObservedObject var state: StateController
    @State private var bob = false
    @State private var walk = false
    @State private var shakeAngle: Double = 0
    @State private var waitingTimer: Timer?

    private func shakeBurst() {
        let steps: [(delay: Double, angle: Double)] = [
            (0.00, -12),
            (0.10,  12),
            (0.20,  -8),
            (0.30,   8),
            (0.42,   0),
        ]
        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                withAnimation(.easeInOut(duration: 0.1)) { shakeAngle = step.angle }
            }
        }
    }

    var pillWidth: CGFloat {
        switch state.state {
        case "idle":     return 220
        case "thinking": return 300
        case "waiting":  return 320
        case "done":     return 340
        case "error":    return 300
        default:         return 220
        }
    }
    var pillHeight: CGFloat {
        // Pill extends from behind the physical notch down to reveal content.
        state.state == "idle" ? 34 : 68 + NOTCH_HEIGHT
    }

    var body: some View {
        VStack {
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 34,
                    bottomTrailingRadius: 34,
                    topTrailingRadius: 0
                )
                .fill(Color.black)
                .frame(width: pillWidth, height: pillHeight)
                .shadow(color: glowColor, radius: state.state == "done" ? 16 : 0)

                if state.state != "idle" {
                    VStack(spacing: 0) {
                        // Reserve the top strip for the physical notch cutout
                        Spacer().frame(height: NOTCH_HEIGHT)
                        // Center content in the remaining (visible) area
                        HStack(spacing: 12) {
                            leftBadge
                            PixelCrab()
                                .offset(
                                    x: state.state == "thinking" ? (walk ? 4 : -4) : 0,
                                    y: state.state == "thinking" && bob ? -2 : 0
                                )
                                .rotationEffect(
                                    state.state == "error"
                                        ? .degrees(bob ? -8 : 8)
                                        : state.state == "waiting"
                                            ? .degrees(shakeAngle)
                                            : .zero,
                                    anchor: .bottom
                                )
                                .animation(
                                    state.state == "thinking"
                                        ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                                        : .easeInOut(duration: 0.12).repeatCount(4, autoreverses: true),
                                    value: bob
                                )
                                .animation(
                                    state.state == "thinking"
                                        ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                                        : .default,
                                    value: walk
                                )
                                .frame(width: 16 * PIXEL_W + 16)
                            rightLabel
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(width: pillWidth, height: pillHeight)
                    .transition(.opacity)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { bob = true; walk = true }
        .onChange(of: state.state) { newState in
            bob.toggle()
            waitingTimer?.invalidate()
            waitingTimer = nil
            shakeAngle = 0
            if newState == "waiting" {
                shakeBurst()
                waitingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                    shakeBurst()
                }
            }
        }
    }

    @ViewBuilder private var leftBadge: some View {
        switch state.state {
        case "done":
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 77/255, green: 191/255, blue: 133/255))
        case "error":
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 224/255, green: 90/255, blue: 69/255))
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var rightLabel: some View {
        let text: String = {
            switch state.state {
            case "thinking": return "Thinking"
            case "waiting":  return "Your turn"
            case "done":     return "Ready"
            case "error":    return "Error"
            default:         return ""
            }
        }()
        HStack(alignment: .bottom, spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.85))
            if state.state == "thinking" {
                PixelThinkingDots()
                    .padding(.bottom, 3)
            }
        }
    }

    private var glowColor: Color {
        switch state.state {
        case "done":    return Color(red: 77/255, green: 191/255, blue: 133/255).opacity(0.55)
        case "waiting": return Color(red: 245/255, green: 197/255, blue: 66/255).opacity(0.55)
        case "error":   return Color(red: 224/255, green: 90/255, blue: 69/255).opacity(0.55)
        default:        return .clear
        }
    }
}

// MARK: - Notch window

class NotchWindow: NSWindow {
    init(contentView: NSView) {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w: CGFloat = 400
        let h: CGFloat = 120
        let x = screen.origin.x + (screen.width - w) / 2
        let y = screen.origin.y + screen.height - h

        super.init(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - State file watcher

final class StateFileWatcher {
    let path: String
    let onChange: (String) -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1

    init(path: String, onChange: @escaping (String) -> Void) {
        self.path = path
        self.onChange = onChange
    }

    func start() {
        if !FileManager.default.fileExists(atPath: path) {
            try? "idle".write(toFile: path, atomically: true, encoding: .utf8)
        }
        fd = open(path, O_EVTONLY)
        if fd < 0 { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.read()
            if src.data.contains(.delete) || src.data.contains(.rename) {
                self?.restart()
            }
        }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd) }
        }
        source = src
        src.resume()
        read()
    }

    private func restart() {
        source?.cancel()
        source = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.start()
        }
    }

    private func read() {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        onChange(contents)
    }
}

// MARK: - App delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    let stateController = StateController()
    var window: NSWindow?
    var watcher: StateFileWatcher?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let host = NSHostingView(rootView: NotchView(state: stateController))
        window = NotchWindow(contentView: host)
        window?.orderFrontRegardless()

        watcher = StateFileWatcher(path: "/tmp/claude-notch-state") { [weak self] value in
            self?.stateController.set(value)
        }
        watcher?.start()

        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = Self.makeMenuIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "Notch Companion"
        }
        let menu = NSMenu()
        for label in ["Idle", "Thinking", "Waiting", "Done", "Error"] {
            let item = NSMenuItem(title: label, action: #selector(setState(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = label.lowercased()
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    private static func makeMenuIcon() -> NSImage {
        let pixelW: CGFloat = 1
        let pixelH: CGFloat = 2
        let cols = 16
        let rows = 8
        let size = NSSize(width: CGFloat(cols) * pixelW, height: CGFloat(rows) * pixelH)
        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.setShouldAntialias(false)
            // Black body pixels (NSImage y-axis is bottom-up, so flip rows)
            ctx.setFillColor(NSColor.black.cgColor)
            for (x, y) in CRAB_BODY {
                ctx.fill(CGRect(
                    x: CGFloat(x) * pixelW,
                    y: CGFloat(rows - 1 - y) * pixelH,
                    width: pixelW, height: pixelH
                ))
            }
            // White eye pixels
            ctx.setFillColor(NSColor.white.cgColor)
            for (x, y) in CRAB_EYES {
                ctx.fill(CGRect(
                    x: CGFloat(x) * pixelW,
                    y: CGFloat(rows - 1 - y) * pixelH,
                    width: pixelW, height: pixelH
                ))
            }
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    @objc private func setState(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String else { return }
        try? s.write(toFile: "/tmp/claude-notch-state", atomically: true, encoding: .utf8)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: - Bootstrap

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
