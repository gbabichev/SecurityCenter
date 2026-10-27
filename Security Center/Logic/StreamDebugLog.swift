import Foundation

extension Notification.Name {
    static let streamDebugLoggingChanged = Notification.Name("StreamDebugLoggingChanged")
}

/// A bounded, serial disk writer; VLC can call it from decoder threads.
nonisolated final class StreamDebugLog: @unchecked Sendable {
    static let shared = StreamDebugLog()
    let directoryURL: URL
    var fileURL: URL { directoryURL.appendingPathComponent("stream-debug.log") }
    private let queue = DispatchQueue(label: "SecurityCenter.StreamDebugLog", qos: .utility)
    private let lock = NSLock()
    private var enabled = false
    private var secrets = Set<String>()
    private var pending = 0
    private var dropped = 0
    private var handle: FileHandle?
    private var bytesWritten: UInt64 = 0
    private let maximumBytes: UInt64
    private let archiveCount = 3

    init(directoryURL: URL? = nil, maximumBytes: UInt64 = 5 * 1024 * 1024) {
        self.maximumBytes = maximumBytes
        self.directoryURL = directoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Security Center/Logs", isDirectory: true)
    }

    var isEnabled: Bool { lock.withLock { enabled } }

    func registerSecrets(_ values: [String]) {
        lock.withLock {
            for value in values where !value.isEmpty {
                secrets.insert(value)
                if let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) { secrets.insert(encoded) }
                if let encoded = value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) { secrets.insert(encoded) }
            }
        }
    }

    func registerCredentials(in url: URL?) {
        guard let url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        registerSecrets([parts.user, parts.password, parts.percentEncodedUser, parts.percentEncodedPassword].compactMap { $0 })
    }

    func setEnabled(_ value: Bool) throws {
        if !value { lock.withLock { enabled = false } }
        try queue.sync {
            if value {
                try openFile()
                lock.withLock { enabled = true }
                append("SESSION", "Debug logging enabled. app=\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown") build=\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown") os=\(ProcessInfo.processInfo.operatingSystemVersionString)")
            } else {
                if handle != nil { append("SESSION", "Debug logging disabled.") }
                try handle?.synchronize()
                try handle?.close()
                handle = nil
            }
        }
    }

    func write(_ category: String, _ message: @autoclosure () -> String) {
        let accepted = lock.withLock {
            guard enabled else { return false }
            guard pending < 1000 else { dropped += 1; return false }
            pending += 1
            return true
        }
        guard accepted else { return }
        let value = message()
        queue.async { [self] in
            defer { lock.withLock { pending -= 1 } }
            guard isEnabled else { return }
            let skipped = lock.withLock { let count = dropped; dropped = 0; return count }
            if skipped > 0 { append("LOGGER", "Dropped \(skipped) messages because the write queue was full.") }
            append(category, value)
        }
    }

    /// Used when stopping logging and by regression checks, not on the playback path.
    func flush() { queue.sync { try? handle?.synchronize() } }

    func redacted(_ message: String) -> String {
        var value = message
        // Drop complete URLs and authentication headers before replacing registered secrets.
        for pattern in [#"(?i)\b(?:rtsps?|https?)://[^\s\"'<>]+"#,
                        #"(?im)\b(?:proxy-)?authorization\s*[:=][^\r\n]*"#,
                        #"(?i)\b(?:password|passwd|pwd|username|user)\s*[:=]\s*(?:\"[^\"]*\"|'[^']*'|[^\s&;,]+)"#] {
            value = value.replacingOccurrences(of: pattern, with: "[redacted]", options: .regularExpression)
        }
        let knownSecrets = lock.withLock { secrets.sorted { $0.count > $1.count } }
        for secret in knownSecrets { value = value.replacingOccurrences(of: secret, with: "[redacted]") }
        return value
    }

    private func openFile() throws {
        guard handle == nil else { return }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            _ = FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        handle = try FileHandle(forWritingTo: fileURL)
        bytesWritten = try handle!.seekToEnd()
    }

    private func append(_ category: String, _ message: String) {
        do {
            try openFile()
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let safe = redacted(message).replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
            let data = Data("\(timestamp) [\(category)] \(safe.prefix(8192))\n".utf8)
            if bytesWritten + UInt64(data.count) > maximumBytes { try rotate() }
            try handle?.write(contentsOf: data)
            bytesWritten += UInt64(data.count)
        } catch {
            // Disk failures must never interfere with camera playback.
            NSLog("Security Center could not write its debug log: %@", error.localizedDescription)
        }
    }

    private func rotate() throws {
        try handle?.close()
        handle = nil
        let manager = FileManager.default
        let oldest = directoryURL.appendingPathComponent("stream-debug.\(archiveCount).log")
        if manager.fileExists(atPath: oldest.path) { try manager.removeItem(at: oldest) }
        for index in stride(from: archiveCount - 1, through: 1, by: -1) {
            let source = directoryURL.appendingPathComponent("stream-debug.\(index).log")
            if manager.fileExists(atPath: source.path) {
                try manager.moveItem(at: source, to: directoryURL.appendingPathComponent("stream-debug.\(index + 1).log"))
            }
        }
        if manager.fileExists(atPath: fileURL.path) {
            try manager.moveItem(at: fileURL, to: directoryURL.appendingPathComponent("stream-debug.1.log"))
        }
        bytesWritten = 0
        try openFile()
    }
}
