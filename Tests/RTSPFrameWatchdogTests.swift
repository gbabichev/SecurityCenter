import Foundation

@main
struct RTSPFrameWatchdogTests {
    static func main() {
        // Steady pictures, including a visually static scene, keep increasing VLC's counter.
        var healthy = RTSPFrameWatchdog(now: 0)
        for tick in 1...300 {
            precondition(!healthy.observe(displayedPictures: Int32(tick), now: Double(tick * 2)))
        }

        var frozen = RTSPFrameWatchdog(now: 0)
        precondition(!frozen.observe(displayedPictures: 100, now: 2))
        for second in stride(from: 4, through: 20, by: 2) {
            precondition(!frozen.observe(displayedPictures: 100, now: Double(second)))
        }
        precondition(frozen.observe(displayedPictures: 100, now: 22), "Frozen video must recover")
        precondition(!frozen.observe(displayedPictures: 100, now: 24), "Only one reconnect per stall")

        var startup = RTSPFrameWatchdog(now: 0)
        for second in stride(from: 2, through: 28, by: 2) {
            precondition(!startup.observe(displayedPictures: 0, now: Double(second)))
        }
        precondition(startup.observe(displayedPictures: 0, now: 30), "No initial video must time out")

        var briefStall = RTSPFrameWatchdog(now: 0)
        for second in stride(from: 2, through: 18, by: 2) {
            precondition(!briefStall.observe(displayedPictures: 10, now: Double(second)))
        }
        precondition(!briefStall.observe(displayedPictures: 11, now: 20))
        precondition(!briefStall.observe(displayedPictures: 11, now: 22))

        var waking = RTSPFrameWatchdog(now: 0)
        precondition(!waking.observe(displayedPictures: 50, now: 2))
        precondition(!waking.observe(displayedPictures: 50, now: 3600), "Wake needs a fresh allowance")
        for second in stride(from: 3602, through: 3618, by: 2) {
            precondition(!waking.observe(displayedPictures: 50, now: Double(second)))
        }
        precondition(waking.observe(displayedPictures: 50, now: 3620))

        var reset = RTSPFrameWatchdog(now: 0)
        precondition(!reset.observe(displayedPictures: 100, now: 2))
        precondition(!reset.observe(displayedPictures: 0, now: 4))
        for second in stride(from: 6, through: 32, by: 2) {
            precondition(!reset.observe(displayedPictures: 0, now: Double(second)))
        }
        precondition(reset.observe(displayedPictures: 0, now: 34))
        print("PASS: healthy frames, startup timeout, sustained stall, brief recovery, wake grace, counter reset, and single recovery")
    }
}
