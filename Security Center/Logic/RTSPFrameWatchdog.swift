import Foundation

/// Tracks rendered frames, not network traffic or decoder activity.
struct RTSPFrameWatchdog {
    static let sampleInterval: TimeInterval = 2
    private let startupAllowance: TimeInterval = 30
    private let stallAllowance: TimeInterval = 20
    private let maximumSampleGap: TimeInterval = 10
    private var lastSampleAt: TimeInterval
    private var lastProgressAt: TimeInterval
    private var previousDisplayed: Int32?
    private var hasDisplayedFrame = false
    private var reportedStall = false

    init(now: TimeInterval) {
        lastSampleAt = now
        lastProgressAt = now
    }

    mutating func observe(displayedPictures: Int32, now: TimeInterval) -> Bool {
        // A suspended app or sleeping Mac is not evidence that the camera stalled.
        if now < lastSampleAt || now - lastSampleAt > maximumSampleGap {
            self = Self(now: now)
        }
        lastSampleAt = now
        guard !reportedStall else { return false }

        if let previousDisplayed, displayedPictures < previousDisplayed {
            // VLC can reset its counters when recreating video output.
            lastProgressAt = now
            hasDisplayedFrame = false
        } else if displayedPictures > (previousDisplayed ?? 0) {
            lastProgressAt = now
            hasDisplayedFrame = true
        }
        previousDisplayed = displayedPictures

        let allowance = hasDisplayedFrame ? stallAllowance : startupAllowance
        guard now - lastProgressAt >= allowance else { return false }
        reportedStall = true
        return true
    }
}
