import Foundation

struct OnionAddress {
    static let base32Alphabet = "abcdefghijklmnopqrstuvwxyz234567"

    static func encodeBase32(_ data: Data) -> String {
        var result = ""
        var value = 0
        var bits = 0

        for byte in data {
            value = (value << 8) | Int(byte)
            bits += 8

            while bits >= 5 {
                let index = (value >> (bits - 5)) & 0x1F
                result.append(base32Alphabet[String.Index(utf16Offset: index, in: base32Alphabet)])
                bits -= 5
            }
        }

        return result
    }

    static func generate(onionFrom publicKey: Data) -> String {
        let sha3 = SHA3()!
        let hash = sha3.hashPublicKeys([publicKey]).first!
        let onionData = hash.prefix(7)  // 最初の 56 ビット (7 バイト)
        return encodeBase32(onionData) + ".onion"
    }
}
