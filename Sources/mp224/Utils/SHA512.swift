import CommonCrypto
import Foundation

struct SHA512 {
    static func hash(_ data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA512(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return Data(hash)
    }
}
