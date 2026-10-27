import Foundation

@main
struct StreamDebugLogTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SecurityCenterLogTests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let log = StreamDebugLog(directoryURL: root)
        log.write("TEST", "disabled message")
        log.flush()
        precondition(!FileManager.default.fileExists(atPath: log.fileURL.path), "Disabled logging created a file")
        log.registerSecrets(["SecretUser", "p@ss word&123"])
        log.registerCredentials(in: URL(string: "rtsp://CameraUser:CameraSecret@192.0.2.1/live"))
        try log.setEnabled(true)
        log.write("TEST", "rtsp://SecretUser:p%40ss%20word%26123@192.0.2.1/live?password=another-secret")
        log.write("TEST", "Authorization: Basic c2VjcmV0\npassword=unregistered-secret user=OtherUser")
        log.write("TEST", "standalone p@ss word&123 CameraSecret SecretUser")
        DispatchQueue.concurrentPerform(iterations: 100) { index in log.write("TEST", "concurrent-\(index)") }
        log.flush()
        let text = try String(contentsOf: log.fileURL, encoding: .utf8)
        for secret in ["SecretUser", "p%40ss", "p@ss word&123", "CameraSecret", "another-secret", "c2VjcmV0", "unregistered-secret", "OtherUser"] {
            precondition(!text.contains(secret), "Credential redaction failed")
        }
        precondition(text.components(separatedBy: "concurrent-").count == 101, "Concurrent messages were lost")
        try log.setEnabled(false)
        let stopped = try Data(contentsOf: log.fileURL)
        log.write("TEST", "after-disable")
        log.flush()
        let afterDisable = try Data(contentsOf: log.fileURL)
        precondition(afterDisable == stopped, "Logging continued after disable")
        let restarted = StreamDebugLog(directoryURL: root)
        try restarted.setEnabled(true)
        restarted.write("TEST", "after-restart")
        restarted.flush()
        let appended = try String(contentsOf: restarted.fileURL, encoding: .utf8)
        precondition(appended.contains("concurrent-99") && appended.contains("after-restart"), "Restart truncated the log")
        try restarted.setEnabled(false)

        let rotating = StreamDebugLog(directoryURL: root.appendingPathComponent("rotation"), maximumBytes: 1024)
        try rotating.setEnabled(true)
        for index in 0..<60 {
            rotating.write("TEST", "marker-\(index) " + String(repeating: "x", count: 150))
            rotating.flush()
        }
        try rotating.setEnabled(false)
        let files = try FileManager.default.contentsOfDirectory(at: rotating.directoryURL, includingPropertiesForKeys: [.fileSizeKey])
        precondition(files.count == 4, "Expected one active log and three archives")
        for file in files {
            let fileSize = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize!
            precondition(fileSize <= 1024, "Rotation exceeded its size limit")
        }
        let retained = try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        precondition(retained.contains("marker-59") && !retained.contains("marker-0 "), "Rotation did not retain the newest records")
        print("PASS: disabled logging, credential redaction, concurrent writes, restart retention, and bounded rotation")
    }
}
