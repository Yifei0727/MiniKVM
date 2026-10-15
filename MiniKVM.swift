import Cocoa
import AVFoundation
import CoreMedia
import CoreVideo
import CoreText
import Darwin

// MARK: - USB HID Keycode Mapping (macOS Virtual KeyCode -> USB HID Usage ID Page 0x07)

struct HIDKeyMap {
    static let macToHID: [UInt16: UInt8] = [
        // Letters A-Z
        0x00: 0x04, // A
        0x0B: 0x05, // B
        0x08: 0x06, // C
        0x02: 0x07, // D
        0x0E: 0x08, // E
        0x03: 0x09, // F
        0x05: 0x0A, // G
        0x04: 0x0B, // H
        0x22: 0x0C, // I
        0x26: 0x0D, // J
        0x28: 0x0E, // K
        0x25: 0x0F, // L
        0x2E: 0x10, // M
        0x2D: 0x11, // N
        0x1F: 0x12, // O
        0x23: 0x13, // P
        0x0C: 0x14, // Q
        0x0F: 0x15, // R
        0x01: 0x16, // S
        0x11: 0x17, // T
        0x20: 0x18, // U
        0x09: 0x19, // V
        0x0D: 0x1A, // W
        0x07: 0x1B, // X
        0x10: 0x1C, // Y
        0x06: 0x1D, // Z

        // Top row numbers 1-0
        0x12: 0x1E, // 1
        0x13: 0x1F, // 2
        0x14: 0x20, // 3
        0x15: 0x21, // 4
        0x17: 0x22, // 5
        0x16: 0x23, // 6
        0x1A: 0x24, // 7
        0x1C: 0x25, // 8
        0x19: 0x26, // 9
        0x1D: 0x27, // 0

        // Control & Whitespace
        0x24: 0x28, // Return / Enter
        0x35: 0x29, // Escape
        0x33: 0x2A, // Backspace (Delete)
        0x30: 0x2B, // Tab
        0x31: 0x2C, // Space
        0x39: 0x39, // CapsLock

        // Punctuation
        0x1B: 0x2D, // - _
        0x18: 0x2E, // = +
        0x21: 0x2F, // [ {
        0x1E: 0x30, // ] }
        0x2A: 0x31, // \ |
        0x29: 0x33, // ; :
        0x27: 0x34, // ' "
        0x32: 0x35, // ` ~
        0x2B: 0x36, // , <
        0x2F: 0x37, // . >
        0x2C: 0x38, // / ?

        // Function Keys F1-F12
        0x7A: 0x3A, // F1
        0x78: 0x3B, // F2
        0x63: 0x3C, // F3
        0x76: 0x3D, // F4
        0x60: 0x3E, // F5
        0x61: 0x3F, // F6
        0x62: 0x40, // F7
        0x64: 0x41, // F8
        0x65: 0x42, // F9
        0x6D: 0x43, // F10
        0x67: 0x44, // F11
        0x6F: 0x45, // F12

        // Navigation
        0x72: 0x49, // Insert / Help
        0x73: 0x4A, // Home
        0x74: 0x4B, // PageUp
        0x75: 0x4C, // Forward Delete
        0x77: 0x4D, // End
        0x79: 0x4E, // PageDown
        0x7C: 0x4F, // Right Arrow
        0x7B: 0x50, // Left Arrow
        0x7D: 0x51, // Down Arrow
        0x7E: 0x52, // Up Arrow

        // Keypad
        0x47: 0x53, // NumLock / Clear
        0x4B: 0x54, // KP /
        0x43: 0x55, // KP *
        0x4E: 0x56, // KP -
        0x45: 0x57, // KP +
        0x4C: 0x58, // KP Enter
        0x53: 0x59, // KP 1
        0x54: 0x5A, // KP 2
        0x55: 0x5B, // KP 3
        0x56: 0x5C, // KP 4
        0x57: 0x5D, // KP 5
        0x58: 0x5E, // KP 6
        0x59: 0x5F, // KP 7
        0x5B: 0x60, // KP 8
        0x5C: 0x61, // KP 9
        0x52: 0x62, // KP 0
        0x41: 0x63  // KP .
    ]

    // When holding Fn (Globe) + Top-Row 1..0/-/=, map directly to F1..F12 so macOS never intercepts Option+F1/F2/F10/F12
    static let fnNumberToFKeyHID: [UInt16: (UInt8, String)] = [
        0x12: (0x3A, "F1"),  // Fn + 1 -> F1
        0x13: (0x3B, "F2"),  // Fn + 2 -> F2
        0x14: (0x3C, "F3"),  // Fn + 3 -> F3
        0x15: (0x3D, "F4"),  // Fn + 4 -> F4
        0x17: (0x3E, "F5"),  // Fn + 5 -> F5
        0x16: (0x3F, "F6"),  // Fn + 6 -> F6
        0x1A: (0x40, "F7"),  // Fn + 7 -> F7
        0x1C: (0x41, "F8"),  // Fn + 8 -> F8
        0x19: (0x42, "F9"),  // Fn + 9 -> F9
        0x1D: (0x43, "F10"), // Fn + 0 -> F10
        0x1B: (0x44, "F11"), // Fn + - -> F11
        0x18: (0x45, "F12")  // Fn + = -> F12
    ]

    // Clean single-line display names for special HID keycodes (avoids "\r" or "\n" breaking status bar layout)
    static let specialHIDNames: [UInt8: String] = [
        0x28: "Enter ↵",
        0x29: "Esc",
        0x2A: "Backspace ⌫",
        0x2B: "Tab ⇥",
        0x2C: "Space ␣",
        0x39: "CapsLock",
        0x3A: "F1", 0x3B: "F2", 0x3C: "F3", 0x3D: "F4",
        0x3E: "F5", 0x3F: "F6", 0x40: "F7", 0x41: "F8",
        0x42: "F9", 0x43: "F10", 0x44: "F11", 0x45: "F12",
        0x49: "Insert",
        0x4A: "Home",
        0x4B: "PageUp",
        0x4C: "Delete ⌦",
        0x4D: "End",
        0x4E: "PageDown",
        0x4F: "Right →",
        0x50: "Left ←",
        0x51: "Down ↓",
        0x52: "Up ↑",
        0x53: "NumLock",
        0x58: "KP_Enter ↵"
    ]

    static func displayName(for hidCode: UInt8, event: NSEvent) -> String {
        if let special = specialHIDNames[hidCode] {
            return special
        }
        if let chars = event.charactersIgnoringModifiers?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .controlCharacters),
           !chars.isEmpty {
            return chars.uppercased()
        }
        return String(format: "0x%02X", hidCode)
    }

    // ASCII character -> (modifier, hidKeycode) for pasting strings
    static let asciiMap: [Character: (UInt8, UInt8)] = {
        var map: [Character: (UInt8, UInt8)] = [
            "1": (0, 0x1E), "2": (0, 0x1F), "3": (0, 0x20), "4": (0, 0x21),
            "5": (0, 0x22), "6": (0, 0x23), "7": (0, 0x24), "8": (0, 0x25),
            "9": (0, 0x26), "0": (0, 0x27),
            "!": (2, 0x1E), "@": (2, 0x1F), "#": (2, 0x20), "$": (2, 0x21),
            "%": (2, 0x22), "^": (2, 0x23), "&": (2, 0x24), "*": (2, 0x25),
            "(": (2, 0x26), ")": (2, 0x27),
            "\n": (0, 0x28), "\r": (0, 0x28), "\t": (0, 0x2B), " ": (0, 0x2C),
            "-": (0, 0x2D), "_": (2, 0x2D),
            "=": (0, 0x2E), "+": (2, 0x2E),
            "[": (0, 0x2F), "{": (2, 0x2F),
            "]": (0, 0x30), "}": (2, 0x30),
            "\\": (0, 0x31), "|": (2, 0x31),
            ";": (0, 0x33), ":": (2, 0x33),
            "'": (0, 0x34), "\"": (2, 0x34),
            "`": (0, 0x35), "~": (2, 0x35),
            ",": (0, 0x36), "<": (2, 0x36),
            ".": (0, 0x37), ">": (2, 0x37),
            "/": (0, 0x38), "?": (2, 0x38)
        ]
        let scalarsA = Int(UnicodeScalar("a").value)
        let scalarsUpperA = Int(UnicodeScalar("A").value)
        for i in 0..<26 {
            let lower = Character(UnicodeScalar(scalarsA + i)!)
            let upper = Character(UnicodeScalar(scalarsUpperA + i)!)
            let code = UInt8(0x04 + i)
            map[lower] = (0x00, code)
            map[upper] = (0x02, code)
        }
        return map
    }()

    static func describeModifiers(_ mod: UInt8) -> String {
        var parts: [String] = []
        if (mod & 0x01) != 0 { parts.append("Ctrl") }
        if (mod & 0x04) != 0 { parts.append("Alt") }
        if (mod & 0x02) != 0 { parts.append("Shift") }
        if (mod & 0x08) != 0 { parts.append("Win") }
        return parts.joined(separator: "+")
    }
}

// MARK: - Video + Key/Mouse OSD Recorder (MP4 + Event Log)

final class KVMVideoRecorder {
    private let queue = DispatchQueue(label: "com.minikvm.recorder", qos: .userInitiated)
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var eventLogHandle: FileHandle?

    private(set) var isRecording: Bool = false
    private(set) var currentVideoURL: URL?
    private(set) var lastSavedVideoURL: URL?
    private var recordingStartUptime: TimeInterval = 0

    // Recent key & mouse events to burn into the recorded video frames (OSD overlay)
    private struct OverlayEvent {
        let time: TimeInterval
        let label: String
    }
    private var recentEvents: [OverlayEvent] = []
    private var lastMouseState: (normX: Double, normY: Double, buttons: UInt8, time: TimeInterval)?

    var videoSampleQueue: DispatchQueue { queue }

    static func moviesDirectoryURL() -> URL {
        let fm = FileManager.default
        if let movies = fm.urls(for: .moviesDirectory, in: .userDomainMask).first {
            try? fm.createDirectory(at: movies, withIntermediateDirectories: true)
            return movies
        }
        let fallback = fm.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
        try? fm.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    func startRecording() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let dir = Self.moviesDirectoryURL()
        let videoURL = dir.appendingPathComponent("MiniKVM-\(timestamp).mp4")
        let logURL = dir.appendingPathComponent("MiniKVM-\(timestamp)-events.log")

        queue.sync {
            try? FileManager.default.removeItem(at: videoURL)
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            self.eventLogHandle = try? FileHandle(forWritingTo: logURL)
            let header = "# MiniKVM 录制事件日志 (\(timestamp))\n# 格式: [录制相对时间] 事件类型: 详情\n"
            if let data = header.data(using: .utf8) {
                try? self.eventLogHandle?.write(contentsOf: data)
            }

            self.writer = nil
            self.writerInput = nil
            self.adaptor = nil
            self.recentEvents.removeAll()
            self.lastMouseState = nil
            self.currentVideoURL = videoURL
            self.recordingStartUptime = ProcessInfo.processInfo.systemUptime
            self.isRecording = true
        }
        return videoURL
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        queue.async { [weak self] in
            guard let self = self, self.isRecording else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.isRecording = false
            let savedURL = self.currentVideoURL
            self.lastSavedVideoURL = savedURL

            try? self.eventLogHandle?.close()
            self.eventLogHandle = nil

            guard let activeWriter = self.writer, let input = self.writerInput else {
                self.writer = nil
                self.writerInput = nil
                self.adaptor = nil
                DispatchQueue.main.async { completion(savedURL) }
                return
            }

            input.markAsFinished()
            activeWriter.finishWriting {
                self.queue.async {
                    self.writer = nil
                    self.writerInput = nil
                    self.adaptor = nil
                    DispatchQueue.main.async {
                        completion(savedURL)
                    }
                }
            }
        }
    }

    func recordKeyEvent(_ text: String) {
        let now = ProcessInfo.processInfo.systemUptime
        queue.async { [weak self] in
            guard let self = self, self.isRecording else { return }
            self.recentEvents.append(OverlayEvent(time: now, label: "⌨️ \(text)"))
            if self.recentEvents.count > 4 {
                self.recentEvents.removeFirst(self.recentEvents.count - 4)
            }
            self.writeLogEntry("KEY   | \(text)")
        }
    }

    func recordMouseEvent(normX: Double, normY: Double, buttons: UInt8, actionDesc: String?) {
        let now = ProcessInfo.processInfo.systemUptime
        queue.async { [weak self] in
            guard let self = self, self.isRecording else { return }
            self.lastMouseState = (normX: normX, normY: normY, buttons: buttons, time: now)
            if let desc = actionDesc {
                let pctX = Int((normX * 100.0).rounded())
                let pctY = Int((normY * 100.0).rounded())
                let label = "🖱️ \(desc) (\(pctX)%, \(pctY)%)"
                self.recentEvents.append(OverlayEvent(time: now, label: label))
                if self.recentEvents.count > 4 {
                    self.recentEvents.removeFirst(self.recentEvents.count - 4)
                }
                self.writeLogEntry("MOUSE | \(desc) @ x=\(String(format: "%.3f", normX)), y=\(String(format: "%.3f", normY)), btn=0x\(String(format: "%02X", buttons))")
            }
        }
    }

    private func writeLogEntry(_ message: String) {
        guard let handle = eventLogHandle else { return }
        let elapsed = max(0.0, ProcessInfo.processInfo.systemUptime - recordingStartUptime)
        let mins = Int(elapsed) / 60
        let secs = elapsed - Double(mins * 60)
        let line = String(format: "[%02d:%05.2f] %@\n", mins, secs, message)
        if let data = line.data(using: .utf8) {
            try? handle.write(contentsOf: data)
        }
    }

    func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let url = currentVideoURL,
              let srcBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let width = CVPixelBufferGetWidth(srcBuffer)
        let height = CVPixelBufferGetHeight(srcBuffer)
        guard width > 0 && height > 0 else { return }

        // Lazily initialize AVAssetWriter on first frame so dimensions & timestamp match
        if writer == nil {
            do {
                let newWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
                let settings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height
                ]
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                input.expectsMediaDataInRealTime = true

                let attrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height
                ]
                let newAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: input,
                    sourcePixelBufferAttributes: attrs
                )
                if newWriter.canAdd(input) {
                    newWriter.add(input)
                    newWriter.startWriting()
                    newWriter.startSession(atSourceTime: pts)
                    self.writer = newWriter
                    self.writerInput = input
                    self.adaptor = newAdaptor
                }
            } catch {
                return
            }
        }

        guard let input = writerInput,
              let adaptor = adaptor,
              input.isReadyForMoreMediaData,
              let pool = adaptor.pixelBufferPool else {
            return
        }

        var dstBufferOpt: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &dstBufferOpt) == kCVReturnSuccess,
              let dstBuffer = dstBufferOpt else {
            return
        }

        CVPixelBufferLockBaseAddress(srcBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(dstBuffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(dstBuffer, [])
            CVPixelBufferUnlockBaseAddress(srcBuffer, .readOnly)
        }

        guard let srcBase = CVPixelBufferGetBaseAddress(srcBuffer),
              let dstBase = CVPixelBufferGetBaseAddress(dstBuffer) else {
            return
        }

        let srcBPR = CVPixelBufferGetBytesPerRow(srcBuffer)
        let dstBPR = CVPixelBufferGetBytesPerRow(dstBuffer)
        let copyBytes = min(srcBPR, dstBPR)
        for row in 0..<height {
            memcpy(dstBase.advanced(by: row * dstBPR), srcBase.advanced(by: row * srcBPR), copyBytes)
        }

        // Draw Key & Mouse OSD overlay onto the frame if active
        let now = ProcessInfo.processInfo.systemUptime
        recentEvents.removeAll { now - $0.time > 2.6 }
        let hasActiveMouse = (lastMouseState != nil) && (now - lastMouseState!.time <= 2.6)

        if !recentEvents.isEmpty || hasActiveMouse {
            let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
            if let ctx = CGContext(
                data: dstBase,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: dstBPR,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            ) {
                drawOSDOverlay(in: ctx, width: CGFloat(width), height: CGFloat(height), now: now)
            }
        }

        _ = adaptor.append(dstBuffer, withPresentationTime: pts)
    }

    private func drawOSDOverlay(in ctx: CGContext, width: CGFloat, height: CGFloat, now: TimeInterval) {
        // 1. Draw Mouse position / click indicator on video frame
        if let mouse = lastMouseState, now - mouse.time <= 2.6 {
            let mx = CGFloat(mouse.normX) * width
            let my = CGFloat(1.0 - mouse.normY) * height
            let isPressed = mouse.buttons != 0
            let radius: CGFloat = isPressed ? 14.0 : 9.0

            ctx.saveGState()
            if isPressed {
                ctx.setFillColor(CGColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 0.45))
                ctx.fillEllipse(in: CGRect(x: mx - radius, y: my - radius, width: radius * 2, height: radius * 2))
                ctx.setStrokeColor(CGColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 0.95))
            } else {
                ctx.setStrokeColor(CGColor(red: 0.0, green: 0.92, blue: 1.0, alpha: 0.85))
            }
            ctx.setLineWidth(2.5)
            ctx.strokeEllipse(in: CGRect(x: mx - radius, y: my - radius, width: radius * 2, height: radius * 2))
            ctx.restoreGState()
        }

        // 2. Draw Key / Mouse event HUD banner at bottom-right of recorded video
        guard !recentEvents.isEmpty else { return }
        let combinedText = recentEvents.map { $0.label }.joined(separator: "   ▸   ")
        let fontSize = max(16.0, min(28.0, height * 0.025))
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attrStr = NSAttributedString(string: combinedText, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        let textBounds = CTLineGetBoundsWithOptions(line, [])

        let padX: CGFloat = 18.0
        let padY: CGFloat = 10.0
        let boxW = min(width - 40.0, textBounds.width + padX * 2)
        let boxH = textBounds.height + padY * 2
        let boxX = width - boxW - 24.0
        let boxY: CGFloat = 24.0
        let boxRect = CGRect(x: boxX, y: boxY, width: boxW, height: boxH)

        ctx.saveGState()
        let path = CGPath(roundedRect: boxRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(CGColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 0.78))
        ctx.fillPath()

        ctx.addPath(path)
        ctx.setStrokeColor(CGColor(red: 0.20, green: 0.92, blue: 0.48, alpha: 0.85))
        ctx.setLineWidth(2.0)
        ctx.strokePath()

        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: boxX + padX, y: boxY + padY - textBounds.minY)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}

// MARK: - Hoverable Help Button with Popover

final class HelpPopoverButton: NSButton {
    private var trackingArea: NSTrackingArea?
    var onHoverChanged: ((Bool) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }
}

// MARK: - CH9329 Serial Controller

final class CH9329SerialController {
    private var fd: Int32 = -1
    private(set) var currentPort: String = ""
    private(set) var currentBaud: Int = 9600
    private let txQueue = DispatchQueue(label: "com.minikvm.ch9329.tx", qos: .userInteractive)
    private var lastTxTime: TimeInterval = 0

    var isOpen: Bool { fd >= 0 }
    var onStatusUpdate: ((String, Bool) -> Void)?

    func listSerialPorts() -> [String] {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: "/dev") else {
            return []
        }
        let ports = items
            .filter { $0.hasPrefix("cu.usbserial") || $0.hasPrefix("cu.wchusbserial") || $0.hasPrefix("cu.usbmodem") }
            .map { "/dev/" + $0 }
            .sorted()
        return ports
    }

    func connect(port: String, baudPreference: Int?) {
        disconnect()
        guard !port.isEmpty else {
            onStatusUpdate?("未选择串口", false)
            return
        }

        if let fixedBaud = baudPreference {
            if openPort(port: port, baud: fixedBaud) {
                currentPort = port
                currentBaud = fixedBaud
                onStatusUpdate?("已连接 \(URL(fileURLWithPath: port).lastPathComponent) @ \(fixedBaud) bps", true)
            } else {
                let err = String(cString: strerror(errno))
                onStatusUpdate?("串口打开失败: \(err)", false)
            }
            return
        }

        let candidates = [9600, 115200]
        for baud in candidates {
            if openPort(port: port, baud: baud) {
                let infoPkt = Self.buildPacket(cmd: 0x01, data: [])
                _ = writeBytes(infoPkt)
                if let resp = readResponse(timeoutMs: 120),
                   resp.count >= 14, resp[0] == 0x57, resp[1] == 0xAB, resp[3] == 0x81 {
                    let ver = String(format: "v%d.%d", resp[5] >> 4, resp[5] & 0x0F)
                    let usbOk = (resp[6] == 0x01) ? "USB已就绪" : "对端USB未连接"
                    let caps = (resp[7] & 0x02) != 0 ? "Caps:ON" : "Caps:OFF"
                    currentPort = port
                    currentBaud = baud
                    onStatusUpdate?("已连接 \(ver) @ \(baud) (\(usbOk), \(caps))", true)
                    return
                }
                closePort()
            }
        }

        if openPort(port: port, baud: 9600) {
            currentPort = port
            currentBaud = 9600
            onStatusUpdate?("已连接 \(URL(fileURLWithPath: port).lastPathComponent) @ 9600 bps (单向/默认)", true)
        } else {
            let err = String(cString: strerror(errno))
            onStatusUpdate?("串口打开失败: \(err)", false)
        }
    }

    func disconnect() {
        if fd >= 0 {
            sendReleaseAllSync()
            closePort()
        }
        currentPort = ""
    }

    private func openPort(port: String, baud: Int) -> Bool {
        let newFd = Darwin.open(port, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard newFd >= 0 else { return false }

        var tty = termios()
        guard tcgetattr(newFd, &tty) == 0 else {
            Darwin.close(newFd)
            return false
        }
        cfmakeraw(&tty)
        tty.c_cflag |= tcflag_t(CS8 | CREAD | CLOCAL)
        tty.c_cflag &= ~tcflag_t(PARENB | CSTOPB)
        cfsetspeed(&tty, speed_t(baud))
        guard tcsetattr(newFd, TCSANOW, &tty) == 0 else {
            Darwin.close(newFd)
            return false
        }
        tcflush(newFd, TCIOFLUSH)
        self.fd = newFd
        return true
    }

    private func closePort() {
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
    }

    static func buildPacket(cmd: UInt8, data: [UInt8], addr: UInt8 = 0x00) -> [UInt8] {
        var frame: [UInt8] = [0x57, 0xAB, addr, cmd, UInt8(data.count)]
        frame.append(contentsOf: data)
        let sum = frame.reduce(0) { ($0 + Int($1)) & 0xFF }
        frame.append(UInt8(sum))
        return frame
    }

    private func writeBytes(_ bytes: [UInt8]) -> Bool {
        guard fd >= 0 else { return false }
        return bytes.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return false }
            let written = Darwin.write(fd, base, bytes.count)
            return written == bytes.count
        }
    }

    private func readResponse(timeoutMs: Int) -> [UInt8]? {
        guard fd >= 0 else { return nil }
        var buf: [UInt8] = []
        let deadline = Date().timeIntervalSince1970 + Double(timeoutMs) / 1000.0
        var temp = [UInt8](repeating: 0, count: 64)
        while Date().timeIntervalSince1970 < deadline {
            let n = Darwin.read(fd, &temp, temp.count)
            if n > 0 {
                buf.append(contentsOf: temp[0..<n])
                if buf.count >= 5 && buf.count >= 5 + Int(buf[4]) + 1 {
                    break
                }
            } else {
                usleep(5000)
            }
        }
        return buf.isEmpty ? nil : buf
    }

    private func enqueuePacket(_ pkt: [UInt8], minIntervalMs: Double? = nil) {
        let baud = currentBaud
        txQueue.async { [weak self] in
            guard let self = self, self.fd >= 0 else { return }
            let defaultInterval = (baud <= 9600) ? 0.018 : 0.005
            let interval = (minIntervalMs != nil) ? (minIntervalMs! / 1000.0) : defaultInterval
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = now - self.lastTxTime
            if elapsed < interval {
                usleep(useconds_t((interval - elapsed) * 1_000_000))
            }
            _ = self.writeBytes(pkt)
            var trash = [UInt8](repeating: 0, count: 64)
            _ = Darwin.read(self.fd, &trash, trash.count)
            self.lastTxTime = ProcessInfo.processInfo.systemUptime
        }
    }

    func sendKeyboardReport(modifiers: UInt8, keys: [UInt8]) {
        var report = [UInt8](repeating: 0, count: 8)
        report[0] = modifiers
        report[1] = 0x00
        for (i, k) in keys.prefix(6).enumerated() {
            report[2 + i] = k
        }
        let pkt = Self.buildPacket(cmd: 0x02, data: report)
        enqueuePacket(pkt)
    }

    func sendKeyComboTap(modifiers: UInt8, keycode: UInt8) {
        sendKeyboardReport(modifiers: modifiers, keys: [keycode])
        sendKeyboardReport(modifiers: 0x00, keys: [])
    }

    func sendReleaseAll() {
        let pkt = Self.buildPacket(cmd: 0x02, data: [0, 0, 0, 0, 0, 0, 0, 0])
        enqueuePacket(pkt)
        let msPkt = Self.buildPacket(cmd: 0x05, data: [0x01, 0, 0, 0, 0])
        enqueuePacket(msPkt)
    }

    private func sendReleaseAllSync() {
        let pkt = Self.buildPacket(cmd: 0x02, data: [0, 0, 0, 0, 0, 0, 0, 0])
        _ = writeBytes(pkt)
    }

    func sendTextString(_ text: String, appendEnter: Bool = false) {
        txQueue.async { [weak self] in
            guard let self = self, self.fd >= 0 else { return }
            let delayUs: useconds_t = (self.currentBaud <= 9600) ? 18_000 : 6_000
            let releasePkt = Self.buildPacket(cmd: 0x02, data: [0, 0, 0, 0, 0, 0, 0, 0])

            for ch in text {
                guard let (mod, code) = HIDKeyMap.asciiMap[ch] else { continue }
                let pressPkt = Self.buildPacket(cmd: 0x02, data: [mod, 0, code, 0, 0, 0, 0, 0])
                _ = self.writeBytes(pressPkt)
                usleep(delayUs)
                _ = self.writeBytes(releasePkt)
                usleep(delayUs)
                var trash = [UInt8](repeating: 0, count: 64)
                _ = Darwin.read(self.fd, &trash, trash.count)
            }
            if appendEnter {
                let enterPkt = Self.buildPacket(cmd: 0x02, data: [0, 0, 0x28, 0, 0, 0, 0, 0])
                _ = self.writeBytes(enterPkt)
                usleep(delayUs)
                _ = self.writeBytes(releasePkt)
                usleep(delayUs)
            }
            self.lastTxTime = ProcessInfo.processInfo.systemUptime
        }
    }

    // CH9329 Absolute Mouse (CMD 0x04): data = [0x02, buttons, x_L, x_H, y_L, y_H, wheel]
    func sendAbsoluteMouse(buttons: UInt8, normX: Double, normY: Double, wheel: Int8 = 0) {
        let clampedX = max(0.0, min(1.0, normX))
        let clampedY = max(0.0, min(1.0, normY))
        let xVal = UInt16((clampedX * 4095.0).rounded())
        let yVal = UInt16((clampedY * 4095.0).rounded())
        let data: [UInt8] = [
            0x02,
            buttons,
            UInt8(xVal & 0xFF),
            UInt8((xVal >> 8) & 0xFF),
            UInt8(yVal & 0xFF),
            UInt8((yVal >> 8) & 0xFF),
            UInt8(bitPattern: wheel)
        ]
        let pkt = Self.buildPacket(cmd: 0x04, data: data)
        enqueuePacket(pkt, minIntervalMs: (currentBaud <= 9600) ? 20.0 : 6.0)
    }
}

// MARK: - Interactive Video + Keyboard/Mouse Capture View

final class KVMVideoCanvasView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    var videoNaturalSize: CGSize = CGSize(width: 1920, height: 1080)

    var isCapturingInput: Bool = true {
        didSet {
            needsDisplay = true
            onCaptureStateChanged?(isCapturingInput)
        }
    }
    var isMouseSyncEnabled: Bool = false
    var mapCommandToControl: Bool = false

    // Latched modifier bits set from toolbar buttons (Ctrl=0x01, Shift=0x02, Alt=0x04, Win=0x08)
    var latchedModifiers: UInt8 = 0
    var onConsumeLatchedModifiers: (() -> Void)?

    var onCaptureStateChanged: ((Bool) -> Void)?
    var onKeyActivity: ((String) -> Void)?
    weak var serialController: CH9329SerialController?
    weak var videoRecorder: KVMVideoRecorder?

    private var pressedHIDKeys: [UInt8] = []
    private var lastTranslatedKeyByMacCode: [UInt16: UInt8] = [:]
    private var currentModifiers: UInt8 = 0
    private var mouseButtons: UInt8 = 0
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspect
        previewLayer.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isCapturingInput = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        releaseAllKeys()
        isCapturingInput = false
        return true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isCapturingInput {
            NSColor.systemGreen.withAlphaComponent(0.75).setStroke()
            let path = NSBezierPath(rect: bounds.insetBy(dx: 1.5, dy: 1.5))
            path.lineWidth = 3.0
            path.stroke()
        }
    }

    func releaseAllKeys() {
        pressedHIDKeys.removeAll()
        lastTranslatedKeyByMacCode.removeAll()
        currentModifiers = 0
        mouseButtons = 0
        serialController?.sendReleaseAll()
    }

    func computeModifiers(from flags: NSEvent.ModifierFlags) -> UInt8 {
        var mod: UInt8 = latchedModifiers
        if flags.contains(.shift) { mod |= 0x02 }
        if flags.contains(.option) { mod |= 0x04 }
        if mapCommandToControl {
            if flags.contains(.command) || flags.contains(.control) {
                mod |= 0x01
            }
        } else {
            if flags.contains(.control) { mod |= 0x01 }
            if flags.contains(.command) { mod |= 0x08 }
        }
        return mod
    }

    override func flagsChanged(with event: NSEvent) {
        guard isCapturingInput else {
            super.flagsChanged(with: event)
            return
        }
        let newMod = computeModifiers(from: event.modifierFlags)
        if newMod != currentModifiers {
            currentModifiers = newMod
            serialController?.sendKeyboardReport(modifiers: currentModifiers, keys: pressedHIDKeys)
            let modText = HIDKeyMap.describeModifiers(currentModifiers)
            onKeyActivity?(modText.isEmpty ? "就绪" : "修饰键: \(modText)")
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 0x35 && event.modifierFlags.contains(.control) && event.modifierFlags.contains(.option) {
            releaseAllKeys()
            isCapturingInput = false
            window?.makeFirstResponder(nil)
            onKeyActivity?("已释放键盘捕获 (点击视频区域重新捕获)")
            return
        }

        guard isCapturingInput else {
            super.keyDown(with: event)
            return
        }

        currentModifiers = computeModifiers(from: event.modifierFlags)

        let hidCode: UInt8
        let displayLabel: String
        if event.modifierFlags.contains(.function),
           let (fCode, fName) = HIDKeyMap.fnNumberToFKeyHID[event.keyCode] {
            hidCode = fCode
            displayLabel = fName
        } else if let mapped = HIDKeyMap.macToHID[event.keyCode] {
            hidCode = mapped
            displayLabel = HIDKeyMap.displayName(for: mapped, event: event)
        } else {
            return
        }

        lastTranslatedKeyByMacCode[event.keyCode] = hidCode
        if !pressedHIDKeys.contains(hidCode) {
            if pressedHIDKeys.count < 6 {
                pressedHIDKeys.append(hidCode)
            } else {
                pressedHIDKeys[5] = hidCode
            }
        }
        serialController?.sendKeyboardReport(modifiers: currentModifiers, keys: pressedHIDKeys)
        let modDesc = HIDKeyMap.describeModifiers(currentModifiers)
        let comboStr = modDesc.isEmpty ? displayLabel : "\(modDesc) + \(displayLabel)"
        onKeyActivity?(String(format: "发送: %@ (0x%02X)", comboStr, hidCode))
        videoRecorder?.recordKeyEvent(comboStr)
    }

    override func keyUp(with event: NSEvent) {
        guard isCapturingInput else {
            super.keyUp(with: event)
            return
        }
        if let prevHid = lastTranslatedKeyByMacCode.removeValue(forKey: event.keyCode) {
            pressedHIDKeys.removeAll { $0 == prevHid }
        } else if let hidCode = HIDKeyMap.macToHID[event.keyCode] {
            pressedHIDKeys.removeAll { $0 == hidCode }
        }

        currentModifiers = computeModifiers(from: event.modifierFlags)
        serialController?.sendKeyboardReport(modifiers: currentModifiers, keys: pressedHIDKeys)
    }

    // MARK: - Mouse Event Handling

    private func normalizedVideoPoint(for event: NSEvent) -> (Double, Double)? {
        let pt = convert(event.locationInWindow, from: nil)
        guard bounds.width > 1, bounds.height > 1 else { return nil }

        let viewW = bounds.width
        let viewH = bounds.height
        let videoAspect = (videoNaturalSize.height > 0) ? (videoNaturalSize.width / videoNaturalSize.height) : (16.0 / 9.0)
        let viewAspect = viewW / viewH

        var videoRect = bounds
        if viewAspect > videoAspect {
            let fittedW = viewH * videoAspect
            videoRect = NSRect(x: (viewW - fittedW) / 2.0, y: 0, width: fittedW, height: viewH)
        } else {
            let fittedH = viewW / videoAspect
            videoRect = NSRect(x: 0, y: (viewH - fittedH) / 2.0, width: viewW, height: fittedH)
        }

        guard videoRect.contains(pt) else { return nil }
        let nx = Double((pt.x - videoRect.minX) / videoRect.width)
        let ny = Double(1.0 - (pt.y - videoRect.minY) / videoRect.height)
        return (nx, ny)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isCapturingInput = true
        guard isMouseSyncEnabled, let (nx, ny) = normalizedVideoPoint(for: event) else { return }
        mouseButtons |= 0x01
        serialController?.sendAbsoluteMouse(buttons: mouseButtons, normX: nx, normY: ny)
        videoRecorder?.recordMouseEvent(normX: nx, normY: ny, buttons: mouseButtons, actionDesc: "左键点击")
    }

    override func mouseUp(with event: NSEvent) {
        guard isMouseSyncEnabled, let (nx, ny) = normalizedVideoPoint(for: event) else { return }
        mouseButtons &= ~0x01
        serialController?.sendAbsoluteMouse(buttons: mouseButtons, normX: nx, normY: ny)
        videoRecorder?.recordMouseEvent(normX: nx, normY: ny, buttons: mouseButtons, actionDesc: nil)
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isCapturingInput = true
        guard isMouseSyncEnabled, let (nx, ny) = normalizedVideoPoint(for: event) else { return }
        mouseButtons |= 0x02
        serialController?.sendAbsoluteMouse(buttons: mouseButtons, normX: nx, normY: ny)
        videoRecorder?.recordMouseEvent(normX: nx, normY: ny, buttons: mouseButtons, actionDesc: "右键点击")
    }

    override func rightMouseUp(with event: NSEvent) {
        guard isMouseSyncEnabled, let (nx, ny) = normalizedVideoPoint(for: event) else { return }
        mouseButtons &= ~0x02
        serialController?.sendAbsoluteMouse(buttons: mouseButtons, normX: nx, normY: ny)
        videoRecorder?.recordMouseEvent(normX: nx, normY: ny, buttons: mouseButtons, actionDesc: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isMouseSyncEnabled, let (nx, ny) = normalizedVideoPoint(for: event) else { return }
        serialController?.sendAbsoluteMouse(buttons: mouseButtons, normX: nx, normY: ny)
        videoRecorder?.recordMouseEvent(normX: nx, normY: ny, buttons: mouseButtons, actionDesc: nil)
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard isMouseSyncEnabled, let (nx, ny) = normalizedVideoPoint(for: event) else { return }
        serialController?.sendAbsoluteMouse(buttons: mouseButtons, normX: nx, normY: ny)
        videoRecorder?.recordMouseEvent(normX: nx, normY: ny, buttons: mouseButtons, actionDesc: nil)
    }

    override func mouseMoved(with event: NSEvent) {
        guard isCapturingInput && isMouseSyncEnabled, let (nx, ny) = normalizedVideoPoint(for: event) else { return }
        serialController?.sendAbsoluteMouse(buttons: mouseButtons, normX: nx, normY: ny)
        videoRecorder?.recordMouseEvent(normX: nx, normY: ny, buttons: mouseButtons, actionDesc: nil)
    }

    override func scrollWheel(with event: NSEvent) {
        guard isCapturingInput && isMouseSyncEnabled, let (nx, ny) = normalizedVideoPoint(for: event) else { return }
        let dy = event.scrollingDeltaY
        if abs(dy) > 0.1 {
            let wheelStep: Int8 = (dy > 0) ? 1 : -1
            serialController?.sendAbsoluteMouse(buttons: mouseButtons, normX: nx, normY: ny, wheel: wheelStep)
            videoRecorder?.recordMouseEvent(normX: nx, normY: ny, buttons: mouseButtons, actionDesc: dy > 0 ? "滚轮向上" : "滚轮向下")
        }
    }
}

// MARK: - Main KVM Controller & Window UI

final class KVMMainWindowController: NSObject, NSWindowDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let window: NSWindow
    let serial = CH9329SerialController()
    let recorder = KVMVideoRecorder()
    let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var currentVideoInput: AVCaptureDeviceInput?
    private var videoDevices: [AVCaptureDevice] = []
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    // Row 1 Controls
    private let cameraPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let serialPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let baudPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let refreshButton = NSButton(title: "刷新", target: nil, action: nil)
    private let captureToggleBtn = NSButton(title: "🟢 键盘捕获", target: nil, action: nil)
    private let cmdMapCheckbox = NSButton(checkboxWithTitle: "Cmd➔Ctrl", target: nil, action: nil)
    private let mouseCheckbox = NSButton(checkboxWithTitle: "鼠标同步", target: nil, action: nil)
    private let recordButton = NSButton(title: "⏺ 录制视频", target: nil, action: nil)
    private let openMoviesBtn = NSButton(title: "📂", target: nil, action: nil)
    private let helpButton = HelpPopoverButton(frame: .zero)
    private let helpPopover = NSPopover()
    private var isHelpPinned = false

    // Row 2 Controls: Paste text + Latchable Modifiers + F1..F12 + Preset Combos
    private let pasteField = NSTextField(frame: .zero)
    private let sendTextBtn = NSButton(title: "发送文本", target: nil, action: nil)
    private let sendEnterCheckbox = NSButton(checkboxWithTitle: "+回车", target: nil, action: nil)
    private let latchCtrlBtn = NSButton(checkboxWithTitle: "Ctrl", target: nil, action: nil)
    private let latchAltBtn = NSButton(checkboxWithTitle: "Alt", target: nil, action: nil)
    private let latchShiftBtn = NSButton(checkboxWithTitle: "Shift", target: nil, action: nil)
    private let presetComboPopup = NSPopUpButton(frame: .zero, pullsDown: true)

    private let videoCanvas = KVMVideoCanvasView(frame: .zero)
    private let statusLabel = NSTextField(labelWithString: "正在初始化...")
    private let keyStatusLabel = NSTextField(labelWithString: "就绪 (鼠标移至右上角 ? 查看按键规则)")

    private static let helpRulesText = """
    ⌨️ MiniKVM 键盘、组合键与视频录制说明

    1. 绕过 macOS 系统拦截输入 F1 ~ F12（推荐）
       macOS 默认会拦截 Option+F1/F2（显示器设置）与 F10/F11/F12（音量/桌面）。
       在视频区域内按住左下角【Fn (地球键) + 顶部数字键】即可直接发送 F1~F12：
       • Fn + 1 ~ 9   ➔  F1 ~ F9
       • Fn + 0       ➔  F10
       • Fn + -       ➔  F11
       • Fn + =       ➔  F12

    2. 常见组合键按法示例（焦点在视频画面内）
       • Alt + F1          ➔  Fn + Option + 1
       • Alt + F2          ➔  Fn + Option + 2
       • Ctrl + Alt + F6   ➔  Fn + Control + Option + 6
       • F10 / F12         ➔  Fn + 0  /  Fn + =

    3. 工具栏快捷触发方式
       • 锁定修饰键：先勾选第二排的【Ctrl】或【Alt】，再点右侧按键或敲击键盘。
       • 下拉菜单：点击【F1-F12 / 组合键 ▾】可一键发送 TTY1~7、Alt+F1~F6、BIOS 键等。

    4. 视频与键鼠轨迹同步录制（⏺ 录制视频）
       • 点击顶部【⏺ 录制视频】自动保存到系统“影片”目录（~/Movies/MiniKVM-yyyy-MM-dd-HH-mm-ss.mp4）。
       • 录制期间您敲击的按键、组合键及鼠标点击位置会以 OSD 字幕条形式实时合成到视频画面右下角，
         并同步生成同名的 -events.log 时间轴记录文件；点击【📂】可直接在访达中定位录像文件。

    5. 焦点控制
       • 点击黑色视频画面：开启实时键盘捕获（四周亮起绿框）。
       • 按 Ctrl + Option + Esc：立即释放键盘焦点并清空按键状态。
    """

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1220, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "MiniKVM — USB Video + CH340/CH9329 键鼠控制台"
        window.minSize = NSSize(width: 960, height: 560)
        window.delegate = self
        window.center()

        videoCanvas.serialController = serial
        videoCanvas.videoRecorder = recorder
        setupVideoDataOutput()
        setupHelpPopover()
        setupUI()
        setupCallbacks()
        refreshDevices()
    }

    private func setupVideoDataOutput() {
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: recorder.videoSampleQueue)
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        recorder.processVideoSampleBuffer(sampleBuffer)
    }

    private func setupHelpPopover() {
        let vc = NSViewController()
        let label = NSTextField(labelWithString: Self.helpRulesText)
        label.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        label.textColor = .labelColor
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])

        vc.view = container
        helpPopover.contentViewController = vc
        helpPopover.behavior = .transient
        helpPopover.animates = true
    }

    private func setupUI() {
        guard let contentView = window.contentView else { return }

        // Top Bar Row 1: Hardware selectors, capture modes, Video Recording & Help button
        let topRow1 = NSStackView()
        topRow1.orientation = .horizontal
        topRow1.spacing = 6
        topRow1.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 4, right: 12)

        let camLabel = NSTextField(labelWithString: "视频源:")
        cameraPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 135).isActive = true
        cameraPopup.target = self
        cameraPopup.action = #selector(cameraSelectionChanged)

        let serLabel = NSTextField(labelWithString: "串口:")
        serialPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 155).isActive = true
        serialPopup.target = self
        serialPopup.action = #selector(serialSelectionChanged)

        let baudLabel = NSTextField(labelWithString: "波特率:")
        baudPopup.addItems(withTitles: ["自动 (9600/115200)", "9600", "115200", "57600", "38400", "19200"])
        baudPopup.target = self
        baudPopup.action = #selector(serialSelectionChanged)

        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshDevices)

        captureToggleBtn.bezelStyle = .rounded
        captureToggleBtn.target = self
        captureToggleBtn.action = #selector(toggleCaptureMode)

        cmdMapCheckbox.target = self
        cmdMapCheckbox.action = #selector(optionsChanged)

        mouseCheckbox.target = self
        mouseCheckbox.action = #selector(optionsChanged)

        // Video Record Toggle Button + Open Movies Folder Button
        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(toggleRecording)
        recordButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true

        openMoviesBtn.bezelStyle = .rounded
        openMoviesBtn.toolTip = "在访达中打开录制视频目录 (~/Movies)"
        openMoviesBtn.target = self
        openMoviesBtn.action = #selector(openMoviesFolder)

        // Native macOS "?" Help button with single hover popover (no duplicate system toolTip)
        helpButton.title = ""
        helpButton.bezelStyle = .helpButton
        helpButton.toolTip = nil
        helpButton.target = self
        helpButton.action = #selector(helpButtonClicked)
        helpButton.onHoverChanged = { [weak self] hovering in
            guard let self = self else { return }
            if hovering {
                if !self.helpPopover.isShown {
                    self.helpPopover.show(relativeTo: self.helpButton.bounds, of: self.helpButton, preferredEdge: .maxY)
                }
            } else if !self.isHelpPinned {
                self.helpPopover.performClose(nil)
            }
        }

        topRow1.addArrangedSubview(camLabel)
        topRow1.addArrangedSubview(cameraPopup)
        topRow1.addArrangedSubview(serLabel)
        topRow1.addArrangedSubview(serialPopup)
        topRow1.addArrangedSubview(baudLabel)
        topRow1.addArrangedSubview(baudPopup)
        topRow1.addArrangedSubview(refreshButton)
        topRow1.addArrangedSubview(captureToggleBtn)
        topRow1.addArrangedSubview(cmdMapCheckbox)
        topRow1.addArrangedSubview(mouseCheckbox)
        topRow1.addArrangedSubview(recordButton)
        topRow1.addArrangedSubview(openMoviesBtn)
        topRow1.addArrangedSubview(helpButton)

        // Top Bar Row 2: Text sender + Modifier Latch + F1..F12 / Combo shortcuts
        let topRow2 = NSStackView()
        topRow2.orientation = .horizontal
        topRow2.spacing = 6
        topRow2.edgeInsets = NSEdgeInsets(top: 2, left: 12, bottom: 6, right: 12)

        pasteField.placeholderString = "输入或粘贴文本..."
        pasteField.stringValue = "1234ABCD!@#$TEST"
        pasteField.widthAnchor.constraint(equalToConstant: 185).isActive = true
        pasteField.target = self
        pasteField.action = #selector(sendPasteText)

        sendEnterCheckbox.state = .off
        sendEnterCheckbox.controlSize = .small

        sendTextBtn.bezelStyle = .rounded
        sendTextBtn.controlSize = .small
        sendTextBtn.target = self
        sendTextBtn.action = #selector(sendPasteText)

        topRow2.addArrangedSubview(pasteField)
        topRow2.addArrangedSubview(sendEnterCheckbox)
        topRow2.addArrangedSubview(sendTextBtn)

        let sep1 = NSTextField(labelWithString: "|")
        sep1.textColor = .tertiaryLabelColor
        topRow2.addArrangedSubview(sep1)

        let modLabel = NSTextField(labelWithString: "修饰:")
        modLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        topRow2.addArrangedSubview(modLabel)

        for chk in [latchCtrlBtn, latchAltBtn, latchShiftBtn] {
            chk.target = self
            chk.action = #selector(latchModifiersChanged)
            chk.controlSize = .small
            topRow2.addArrangedSubview(chk)
        }

        setupPresetComboMenu()
        topRow2.addArrangedSubview(presetComboPopup)

        let quickBtns: [(String, Int)] = [
            ("Alt+F1", 101),
            ("Alt+F2", 102),
            ("Ctrl+Alt+F6", 206),
            ("F2", 12),
            ("F10", 20),
            ("F12", 22),
            ("Ctrl+Alt+Del", 1),
            ("Esc", 4),
            ("释放按键", 99)
        ]

        for (title, tag) in quickBtns {
            let btn = NSButton(title: title, target: self, action: #selector(quickShortcutClicked(_:)))
            btn.bezelStyle = .rounded
            btn.controlSize = .small
            btn.tag = tag
            topRow2.addArrangedSubview(btn)
        }

        // Bottom Status Bar (strict single-line fixed height so it NEVER expands or shifts video)
        let bottomBar = NSStackView()
        bottomBar.orientation = .horizontal
        bottomBar.alignment = .centerY
        bottomBar.distribution = .fill
        bottomBar.spacing = 12
        bottomBar.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        bottomBar.heightAnchor.constraint(equalToConstant: 26).isActive = true

        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        statusLabel.usesSingleLineMode = true
        statusLabel.maximumNumberOfLines = 1
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        keyStatusLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        keyStatusLabel.textColor = .secondaryLabelColor
        keyStatusLabel.alignment = .right
        keyStatusLabel.usesSingleLineMode = true
        keyStatusLabel.maximumNumberOfLines = 1
        keyStatusLabel.lineBreakMode = .byTruncatingMiddle
        keyStatusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        bottomBar.addArrangedSubview(statusLabel)
        bottomBar.addArrangedSubview(NSView())
        bottomBar.addArrangedSubview(keyStatusLabel)

        // Main Vertical Layout
        let mainStack = NSStackView(views: [topRow1, topRow2, videoCanvas, bottomBar])
        mainStack.orientation = .vertical
        mainStack.spacing = 0
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            videoCanvas.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        videoCanvas.previewLayer.session = captureSession
    }

    private func setupPresetComboMenu() {
        presetComboPopup.controlSize = .small
        presetComboPopup.removeAllItems()
        presetComboPopup.addItem(withTitle: "F1-F12 / 组合键 ▾")

        var items: [(String, UInt8, UInt8)] = []
        for i in 1...12 {
            items.append(("F\(i) (可配左侧修饰键)", 0x00, UInt8(0x3A + i - 1)))
        }
        items.append(contentsOf: [
            ("Alt + F1", 0x04, 0x3A),
            ("Alt + F2", 0x04, 0x3B),
            ("Alt + F3", 0x04, 0x3C),
            ("Alt + F4 (关闭窗口)", 0x04, 0x3D),
            ("Alt + F5", 0x04, 0x3E),
            ("Alt + F6", 0x04, 0x3F),
            ("Ctrl + Alt + F1 (TTY1)", 0x05, 0x3A),
            ("Ctrl + Alt + F2 (TTY2)", 0x05, 0x3B),
            ("Ctrl + Alt + F3 (TTY3)", 0x05, 0x3C),
            ("Ctrl + Alt + F4 (TTY4)", 0x05, 0x3D),
            ("Ctrl + Alt + F5 (TTY5)", 0x05, 0x3E),
            ("Ctrl + Alt + F6 (TTY6)", 0x05, 0x3F),
            ("Ctrl + Alt + F7 (GUI/TTY7)", 0x05, 0x40),
            ("Alt + Tab (切换窗口)", 0x04, 0x2B),
            ("Win / Super 键", 0x08, 0x00),
            ("Win + R (运行)", 0x08, 0x15),
            ("Ctrl + Shift + Esc", 0x03, 0x29)
        ])

        for item in items {
            presetComboPopup.addItem(withTitle: item.0)
            if let menuItem = presetComboPopup.menu?.items.last {
                menuItem.tag = (Int(item.1) << 8) | Int(item.2)
                menuItem.target = self
                menuItem.action = #selector(presetComboSelected(_:))
            }
        }
    }

    private func setupCallbacks() {
        serial.onStatusUpdate = { [weak self] msg, ok in
            DispatchQueue.main.async {
                self?.statusLabel.stringValue = msg
                self?.statusLabel.textColor = ok ? .systemGreen : .systemOrange
            }
        }

        videoCanvas.onCaptureStateChanged = { [weak self] active in
            DispatchQueue.main.async {
                self?.captureToggleBtn.title = active ? "🟢 键盘捕获" : "⚪️ 捕获暂停"
            }
        }

        videoCanvas.onKeyActivity = { [weak self] info in
            DispatchQueue.main.async {
                let clean = info.replacingOccurrences(of: "\r", with: " ")
                                .replacingOccurrences(of: "\n", with: " ")
                self?.keyStatusLabel.stringValue = clean
            }
        }

        videoCanvas.onConsumeLatchedModifiers = { [weak self] in
            DispatchQueue.main.async {
                self?.clearLatchedModifiers()
            }
        }
    }

    // MARK: - Video Recording Actions

    @objc func toggleRecording() {
        if recorder.isRecording {
            stopVideoRecording()
        } else {
            startVideoRecording()
        }
        window.makeFirstResponder(videoCanvas)
    }

    private func startVideoRecording() {
        let outURL = recorder.startRecording()
        recordingStartTime = Date()
        updateRecordingButtonTitle()

        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRecordingButtonTitle()
        }
        keyStatusLabel.stringValue = "⏺ 正在录制至: ~/Movies/\(outURL.lastPathComponent) (含按键/鼠标轨迹)"
    }

    private func stopVideoRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordButton.isEnabled = false
        recordButton.title = "正在保存..."

        recorder.stopRecording { [weak self] savedURL in
            guard let self = self else { return }
            self.recordButton.isEnabled = true
            self.recordButton.title = "⏺ 录制视频"
            self.recordButton.contentTintColor = nil
            if let url = savedURL {
                self.keyStatusLabel.stringValue = "✅ 已保存: ~/Movies/\(url.lastPathComponent)"
            } else {
                self.keyStatusLabel.stringValue = "录制已停止"
            }
        }
    }

    private func updateRecordingButtonTitle() {
        guard let start = recordingStartTime else { return }
        let elapsed = max(0, Int(Date().timeIntervalSince(start)))
        let hrs = elapsed / 3600
        let mins = (elapsed % 3600) / 60
        let secs = elapsed % 60
        let timeStr = (hrs > 0)
            ? String(format: "%02d:%02d:%02d", hrs, mins, secs)
            : String(format: "%02d:%02d", mins, secs)
        recordButton.title = "⏹ \(timeStr)"
        recordButton.contentTintColor = .systemRed
    }

    @objc func openMoviesFolder() {
        if let saved = recorder.lastSavedVideoURL ?? recorder.currentVideoURL,
           FileManager.default.fileExists(atPath: saved.path) {
            NSWorkspace.shared.activateFileViewerSelecting([saved])
        } else {
            NSWorkspace.shared.open(KVMVideoRecorder.moviesDirectoryURL())
        }
        window.makeFirstResponder(videoCanvas)
    }

    @objc func helpButtonClicked() {
        if helpPopover.isShown && isHelpPinned {
            isHelpPinned = false
            helpPopover.performClose(nil)
        } else {
            isHelpPinned = true
            if !helpPopover.isShown {
                helpPopover.show(relativeTo: helpButton.bounds, of: helpButton, preferredEdge: .maxY)
            }
        }
    }

    private func currentLatchedMask() -> UInt8 {
        var mask: UInt8 = 0
        if latchCtrlBtn.state == .on { mask |= 0x01 }
        if latchAltBtn.state == .on { mask |= 0x04 }
        if latchShiftBtn.state == .on { mask |= 0x02 }
        return mask
    }

    private func clearLatchedModifiers() {
        latchCtrlBtn.state = .off
        latchAltBtn.state = .off
        latchShiftBtn.state = .off
        videoCanvas.latchedModifiers = 0
    }

    @objc func latchModifiersChanged() {
        let mask = currentLatchedMask()
        videoCanvas.latchedModifiers = mask
        let desc = HIDKeyMap.describeModifiers(mask)
        keyStatusLabel.stringValue = (mask == 0)
            ? "就绪"
            : "已锁定修饰键: [\(desc)] — 点击右侧按键或敲击键盘自动组合"
        window.makeFirstResponder(videoCanvas)
    }

    @objc func presetComboSelected(_ sender: NSMenuItem) {
        let packed = sender.tag
        let presetMod = UInt8((packed >> 8) & 0xFF)
        let key = UInt8(packed & 0xFF)
        let activeMod = presetMod | videoCanvas.computeModifiers(from: NSEvent.modifierFlags)
        serial.sendKeyComboTap(modifiers: activeMod, keycode: key)
        let modDesc = HIDKeyMap.describeModifiers(activeMod)
        let keyName = HIDKeyMap.specialHIDNames[key] ?? sender.title
        let comboLabel = modDesc.isEmpty ? keyName : "\(modDesc) + \(keyName)"
        keyStatusLabel.stringValue = "已发送: \(comboLabel)"
        recorder.recordKeyEvent(comboLabel)
        window.makeFirstResponder(videoCanvas)
    }

    @objc func refreshDevices() {
        let ports = serial.listSerialPorts()
        serialPopup.removeAllItems()
        if ports.isEmpty {
            serialPopup.addItem(withTitle: "未检测到串口")
        } else {
            serialPopup.addItems(withTitles: ports)
            if let preferredIdx = ports.firstIndex(of: "/dev/cu.usbserial-1410") {
                serialPopup.selectItem(at: preferredIdx)
            } else {
                serialPopup.selectItem(at: 0)
            }
        }
        serialSelectionChanged()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            discoverAndSelectCameras()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.discoverAndSelectCameras()
                    } else {
                        self?.keyStatusLabel.stringValue = "未授予摄像头权限，请在系统设置中开启"
                    }
                }
            }
        default:
            keyStatusLabel.stringValue = "摄像头权限受限，请在系统设置中允许访问摄像头"
        }
    }

    private func discoverAndSelectCameras() {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            deviceTypes.insert(.external, at: 0)
        }
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        videoDevices = session.devices.sorted { a, b in
            let aUSB = a.localizedName.localizedCaseInsensitiveContains("USB")
            let bUSB = b.localizedName.localizedCaseInsensitiveContains("USB")
            if aUSB != bUSB { return aUSB }
            return a.localizedName < b.localizedName
        }

        cameraPopup.removeAllItems()
        if videoDevices.isEmpty {
            cameraPopup.addItem(withTitle: "未找到视频输入设备")
            return
        }

        for dev in videoDevices {
            cameraPopup.addItem(withTitle: dev.localizedName)
        }
        cameraPopup.selectItem(at: 0)
        cameraSelectionChanged()
    }

    @objc func cameraSelectionChanged() {
        let idx = cameraPopup.indexOfSelectedItem
        guard idx >= 0 && idx < videoDevices.count else { return }
        let selectedDevice = videoDevices[idx]

        captureSession.beginConfiguration()
        if let existing = currentVideoInput {
            captureSession.removeInput(existing)
            currentVideoInput = nil
        }

        do {
            let input = try AVCaptureDeviceInput(device: selectedDevice)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentVideoInput = input
            }
            let dims = CMVideoFormatDescriptionGetDimensions(selectedDevice.activeFormat.formatDescription)
            if dims.width > 0 && dims.height > 0 {
                videoCanvas.videoNaturalSize = CGSize(width: Int(dims.width), height: Int(dims.height))
            }
        } catch {
            keyStatusLabel.stringValue = "打开视频源失败: \(error.localizedDescription)"
        }
        captureSession.commitConfiguration()

        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
        window.makeFirstResponder(videoCanvas)
    }

    @objc func serialSelectionChanged() {
        guard let portTitle = serialPopup.selectedItem?.title, portTitle.hasPrefix("/dev/") else {
            serial.disconnect()
            statusLabel.stringValue = "未连接串口"
            statusLabel.textColor = .systemOrange
            return
        }
        let baudTitle = baudPopup.selectedItem?.title ?? ""
        let baudPref = Int(baudTitle)
        serial.connect(port: portTitle, baudPreference: baudPref)
    }

    @objc func toggleCaptureMode() {
        if videoCanvas.isCapturingInput {
            videoCanvas.releaseAllKeys()
            videoCanvas.isCapturingInput = false
            window.makeFirstResponder(nil)
        } else {
            window.makeFirstResponder(videoCanvas)
            videoCanvas.isCapturingInput = true
        }
    }

    @objc func optionsChanged() {
        videoCanvas.mapCommandToControl = (cmdMapCheckbox.state == .on)
        videoCanvas.isMouseSyncEnabled = (mouseCheckbox.state == .on)
        window.makeFirstResponder(videoCanvas)
    }

    @objc func sendPasteText() {
        let text = pasteField.stringValue
        guard !text.isEmpty else { return }
        let addEnter = (sendEnterCheckbox.state == .on)
        serial.sendTextString(text, appendEnter: addEnter)
        keyStatusLabel.stringValue = "已批量发送 \(text.count) 个字符"
        recorder.recordKeyEvent("批量文本(\(text.count)字符)\(addEnter ? "+Enter" : "")")
        window.makeFirstResponder(videoCanvas)
    }

    @objc func quickShortcutClicked(_ sender: NSButton) {
        let extraMod = videoCanvas.computeModifiers(from: NSEvent.modifierFlags)
        var sentLabel = ""
        switch sender.tag {
        case 1: // Ctrl + Alt + Del
            serial.sendKeyComboTap(modifiers: 0x01 | 0x04, keycode: 0x4C)
            sentLabel = "Ctrl+Alt+Del"
        case 4: // Esc
            serial.sendKeyComboTap(modifiers: extraMod, keycode: 0x29)
            sentLabel = "Esc"
        case 12: // F2
            serial.sendKeyComboTap(modifiers: extraMod, keycode: 0x3B)
            let m = HIDKeyMap.describeModifiers(extraMod)
            sentLabel = m.isEmpty ? "F2" : "\(m)+F2"
        case 20: // F10
            serial.sendKeyComboTap(modifiers: extraMod, keycode: 0x43)
            let m = HIDKeyMap.describeModifiers(extraMod)
            sentLabel = m.isEmpty ? "F10" : "\(m)+F10"
        case 22: // F12
            serial.sendKeyComboTap(modifiers: extraMod, keycode: 0x45)
            let m = HIDKeyMap.describeModifiers(extraMod)
            sentLabel = m.isEmpty ? "F12" : "\(m)+F12"
        case 101: // Alt + F1
            serial.sendKeyComboTap(modifiers: 0x04 | extraMod, keycode: 0x3A)
            sentLabel = "Alt+F1"
        case 102: // Alt + F2
            serial.sendKeyComboTap(modifiers: 0x04 | extraMod, keycode: 0x3B)
            sentLabel = "Alt+F2"
        case 206: // Ctrl + Alt + F6
            serial.sendKeyComboTap(modifiers: 0x01 | 0x04 | extraMod, keycode: 0x3F)
            sentLabel = "Ctrl+Alt+F6"
        case 99: // Release All
            clearLatchedModifiers()
            videoCanvas.releaseAllKeys()
            keyStatusLabel.stringValue = "已释放所有按键"
        default:
            break
        }
        if !sentLabel.isEmpty {
            keyStatusLabel.stringValue = "已发送: \(sentLabel)"
            recorder.recordKeyEvent(sentLabel)
        }
        window.makeFirstResponder(videoCanvas)
    }

    func windowWillClose(_ notification: Notification) {
        recordingTimer?.invalidate()
        if recorder.isRecording {
            let sem = DispatchSemaphore(value: 0)
            recorder.stopRecording { _ in sem.signal() }
            _ = sem.wait(timeout: .now() + 2.0)
        }
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        serial.disconnect()
        NSApp.terminate(nil)
    }
}

// MARK: - AppDelegate & Entry Point

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainController: KVMMainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let icnsPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let iconImg = NSImage(contentsOfFile: icnsPath) {
            NSApp.applicationIconImage = iconImg
        } else if let pngPath = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
                  let iconImg = NSImage(contentsOfFile: pngPath) {
            NSApp.applicationIconImage = iconImg
        }
        setupMainMenu()
        mainController = KVMMainWindowController()
        mainController?.window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出 MiniKVM", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
