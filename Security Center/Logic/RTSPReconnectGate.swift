import Foundation

/// A one-use authorization for the retry that still belongs to the active source.
struct RTSPReconnectGate {
    struct Ticket: Equatable {
        fileprivate let id = UUID()
        let url: URL
    }

    private var pending: Ticket?

    mutating func begin(for url: URL) -> Ticket {
        let ticket = Ticket(url: url)
        pending = ticket
        return ticket
    }

    mutating func cancel() {
        pending = nil
    }

    /// Call on the playback actor immediately before replacing media, with no intervening await.
    mutating func consume(_ ticket: Ticket, currentURL: URL?, isActive: Bool, isCancelled: Bool) -> Bool {
        guard !isCancelled, isActive, currentURL == ticket.url, pending == ticket else { return false }
        pending = nil
        return true
    }
}
