import Foundation
import VLCKitSPM

nonisolated final class VLCStreamLogger: NSObject, VLCLogging {
    var level: VLCLogLevel = .debug

    func handleMessage(_ message: String, logLevel: VLCLogLevel, context: VLCLogContext?) {
        let category = "VLC level=\(logLevel.rawValue) module=\(context?.module ?? "unknown") object=\(context?.objectId ?? 0)"
        StreamDebugLog.shared.write(category, message)
    }
}
