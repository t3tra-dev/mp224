import Foundation

struct KeyFinder {
    let prefix: String
    let threads: Int
    let ed25519: Ed25519
    let sha3: SHA3

    init(prefix: String, threads: Int) {
        self.prefix = prefix
        // Limit threads to avoid GPU resource issues
        self.threads = min(threads, 64)
        guard let ed25519 = Ed25519(), let sha3 = SHA3() else {
            fatalError("❌ Metal 初期化に失敗しました。")
        }
        self.ed25519 = ed25519
        self.sha3 = sha3
    }

    struct KeyPair {
        let onion: String
        let publicKey: Data
        let secretKey: Data
    }

    func find() -> KeyPair {
        var batchCount = 0
        while true {
            if batchCount % 100 == 0 {
                print("🔄 Processed \(batchCount * threads) addresses...")
            }
            
            if let result = autoreleasepool(invoking: { () -> KeyPair? in
                let pairs = ed25519.generateKeys(count: threads).map { pair in
                    let pubBytes = withUnsafeBytes(of: pair) { Array($0) }
                    let secBytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
                    return (Data(pubBytes), Data(secBytes))
                }
                let publicKeys = pairs.map { $0.0 }
                let secretKeys = pairs.map { $0.1 }
                let hashes = sha3.hashPublicKeys(publicKeys)

                for (i, hash) in hashes.enumerated() {
                    let onion = OnionAddress.encodeBase32(hash.prefix(7)) + ".onion"
                    if AddressFilter.matchesPrefix(onion, prefix: prefix) {
                        return KeyPair(onion: onion, publicKey: publicKeys[i], secretKey: secretKeys[i])
                    }
                }
                return nil
            }) {
                return result
            }
            
            batchCount += 1
        }
    }
}
