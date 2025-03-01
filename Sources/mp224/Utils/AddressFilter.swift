import Foundation

struct AddressFilter {
    static func matchesPrefix(_ onion: String, prefix: String) -> Bool {
        return onion.hasPrefix(prefix)
    }
}
