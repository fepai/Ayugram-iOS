import Foundation
import Postbox
import SwiftSignalKit

/// Dependency inversion for the plugin engine: TelegramCore cannot import the
/// JavaScript runtime module (the runtime imports TelegramCore), so the engine
/// registers its outgoing-message processor here at startup.
/// The processor receives every outgoing message batch and returns the batch
/// to keep: it may drop messages (plugin commands) or rewrite their text.
public var _ayuPluginProcessOutgoing: ((Account, PeerId, [(Bool, EnqueueMessage)]) -> [(Bool, EnqueueMessage)])?

func ayuPreparePluginCommands(account: Account, peerId: PeerId, messages: [(Bool, EnqueueMessage)]) -> Signal<[(Bool, EnqueueMessage)], NoError> {
    guard let handler = _ayuPluginProcessOutgoing else {
        return .single(messages)
    }
    return .single(handler(account, peerId, messages))
}
