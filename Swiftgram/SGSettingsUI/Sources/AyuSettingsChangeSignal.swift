import Foundation
import SwiftSignalKit
import SGSimpleSettings

/// Emits on every AyuGram settings, filters or message-filter change so open
/// settings screens rebuild their entries.
func ayuSettingsChangeSignal() -> Signal<Int, NoError> {
    return Signal { subscriber in
        subscriber.putNext(0)
        let observer = NotificationCenter.default.addObserver(forName: AyuGramSettings.didChange, object: nil, queue: .main) { _ in
            subscriber.putNext(0)
        }
        let filtersObserver = NotificationCenter.default.addObserver(forName: AyuGramFilters.didChange, object: nil, queue: .main) { _ in
            subscriber.putNext(0)
        }
        let updateObserver = NotificationCenter.default.addObserver(forName: AyuGramUpdates.didChange, object: nil, queue: .main) { _ in
            subscriber.putNext(0)
        }
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
            NotificationCenter.default.removeObserver(filtersObserver)
            NotificationCenter.default.removeObserver(updateObserver)
        }
    }
}
