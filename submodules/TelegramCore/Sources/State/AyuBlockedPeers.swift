import Foundation
import Postbox
import SwiftSignalKit
import SyncCore

/// Cached "is blocked" answers for message authors, used by the chat renderer
/// when "Hide blocked users" is on. Unknown authors are resolved with an async
/// postbox read; messages already on screen stay until they re-render, so the
/// very first message of a fresh author may need one scroll to disappear.
public final class AyuBlockedPeers {
    public static let shared = AyuBlockedPeers()

    private let lock = NSLock()
    private var known: [Int64: Bool] = [:]
    private var pending: Set<Int64> = []
    private weak var postbox: Postbox?

    /// Called when an account becomes active. Blocked state is per-account, so
    /// switching to another account's postbox drops the cached answers.
    public func attach(postbox: Postbox) {
        lock.lock()
        if self.postbox !== postbox {
            self.postbox = postbox
            known.removeAll()
            pending.removeAll()
        }
        lock.unlock()
    }

    public func isBlocked(_ peerId: PeerId?) -> Bool {
        guard let peerId, peerId.namespace == Namespaces.Peer.CloudUser else {
            return false
        }
        let id = peerId.toInt64()
        lock.lock()
        if let value = known[id] {
            lock.unlock()
            return value
        }
        let needsFetch = !pending.contains(id)
        if needsFetch {
            pending.insert(id)
        }
        let postbox = self.postbox
        lock.unlock()
        if needsFetch, let postbox {
            let _ = (postbox.transaction { transaction -> Bool in
                if let data = transaction.getPeerCachedData(peerId: peerId), let user = data as? CachedUserData {
                    return user.isBlocked
                }
                return false
            }
            |> deliverOnMainQueue).start(next: { [weak self] blocked in
                guard let self else { return }
                self.lock.lock()
                self.known[id] = blocked
                self.pending.remove(id)
                self.lock.unlock()
            })
        }
        return false
    }
}
