import Foundation
import ArgumentParser

struct MP224: ParsableCommand {
    @Argument(help: "検索する .onion アドレスのプレフィックス（例: chatgptxyz）")
    var prefix: String

    @Option(name: .shortAndLong, help: "スレッド数 (デフォルト: 4)")
    var threads: Int = 4

    func run() throws {
        print("🔍 Searching for an .onion address with prefix: \(prefix)")
        let keyFinder = KeyFinder(prefix: prefix, threads: threads)
        let result = keyFinder.find()
        
        print("✅ Found matching .onion address!")
        print("Onion: \(result.onion)")
        print("Public Key: \(result.publicKey.base64EncodedString())")
        print("Secret Key: \(result.secretKey.base64EncodedString())")
    }
}
