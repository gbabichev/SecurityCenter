import Foundation

@main
struct CameraBackdropSourceTests {
    @MainActor
    static func main() {
        var original = CameraConfig.emptyDraft
        original.host = "192.0.2.1"
        original.username = "viewer"
        original.password = "test-password"
        original.feedMode = .rtsp

        var edited = original
        edited.name = "Renamed camera"
        edited.showsNameInDisplay.toggle()
        edited.nameLocation = .bottomRight
        edited.isMuted.toggle()
        edited.useHTTPS.toggle() // Only affects JPG connections.
        edited.snapshotPollingIntervalSeconds = 5
        precondition(edited.backdropSource == original.backdropSource,
                     "RTSP display-only edits must preserve the captured backdrop")

        func expectNewSource(_ change: (inout CameraConfig) -> Void) {
            var changed = original
            change(&changed)
            precondition(changed.backdropSource != original.backdropSource,
                         "A different camera or picture source must invalidate its backdrop")
        }
        expectNewSource { $0.id = UUID() }
        expectNewSource { $0.host = "192.0.2.2" }
        expectNewSource { $0.password = "new-password" }
        expectNewSource { $0.streamVariant = .sub }
        expectNewSource { $0.channel += 1 }
        expectNewSource { $0.feedMode = .snapshotPolling }
        expectNewSource { $0.isEnabled.toggle() }

        original.feedMode = .snapshotPolling
        edited = original
        edited.name = "Renamed JPG camera"
        edited.nameLocation = .bottomRight
        precondition(edited.backdropSource == original.backdropSource)
        expectNewSource { $0.useHTTPS.toggle() }

        original.kind = .genericRTSP
        original.feedMode = .rtsp
        original.genericRTSPURL = "rtsp://192.0.2.1/live"
        expectNewSource { $0.genericRTSPURL = "rtsp://192.0.2.2/live" }
        print("PASS: label edits preserve backdrops; camera, connection, feed, and enabled changes invalidate them")
    }
}
