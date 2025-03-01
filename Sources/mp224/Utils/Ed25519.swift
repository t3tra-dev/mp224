import Metal

struct Ed25519 {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState

    init?() {
        // Get default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal デバイスが見つかりません。")
            return nil
        }
        print("✓ Metal デバイス: \(device.name)")
        self.device = device

        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ Metal コマンドキューの作成に失敗しました。")
            return nil
        }
        print("✓ コマンドキュー作成成功")
        self.commandQueue = commandQueue

        // Find metallib file
        guard let libraryPath = Bundle.module.path(forResource: "default", ofType: "metallib") else {
            print("❌ Metal ライブラリファイルが見つかりません。")
            // Print bundle resources for debugging
            if let resourcePath = Bundle.module.resourcePath {
                print("📁 リソースパス: \(resourcePath)")
                do {
                    let items = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("📄 利用可能なファイル:")
                    items.forEach { print("- \($0)") }
                } catch {
                    print("❌ リソースディレクトリの読み取りに失敗: \(error)")
                }
            }
            return nil
        }
        print("✓ Metallib ファイル: \(libraryPath)")
        
        do {
            // Load library
            let library = try device.makeLibrary(filepath: libraryPath)
            print("✓ Metal ライブラリ読み込み成功")
            
            // Get function
            guard let function = library.makeFunction(name: "generate_public_key") else {
                print("❌ Metal 関数が見つかりません。")
                print("📄 利用可能な関数:")
                library.functionNames.forEach { print("- \($0)") }
                return nil
            }
            print("✓ Metal 関数取得成功")
            
            // Create pipeline state
            self.pipelineState = try device.makeComputePipelineState(function: function)
            print("✓ パイプラインステート作成成功")
        } catch {
            print("❌ Metal シェーダーのコンパイルに失敗しました：\(error)")
            return nil
        }
    }

    func generateKeys(count: Int) -> [(UInt64, UInt64)] {
        print("🔑 鍵生成開始 (count: \(count))")
        
        // Create buffers
        guard let seedBuffer = device.makeBuffer(length: count * 32, options: .storageModeShared) else {
            print("❌ シードバッファの作成に失敗")
            return []
        }
        print("✓ シードバッファ作成成功")
        
        guard let publicKeyBuffer = device.makeBuffer(length: count * 32, options: .storageModeShared) else {
            print("❌ 公開鍵バッファの作成に失敗")
            return []
        }
        print("✓ 公開鍵バッファ作成成功")
            
        // Generate seed data
        let seedPtr = seedBuffer.contents().bindMemory(to: UInt8.self, capacity: count * 32)
        for i in 0..<(count * 32) {
            seedPtr[i] = UInt8.random(in: 0...255)
        }
        print("✓ シードデータ生成成功")

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("❌ コマンドバッファの作成に失敗")
            return []
        }
        print("✓ コマンドバッファ作成成功")
        
        // Create compute encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("❌ コンピュートエンコーダの作成に失敗")
            return []
        }
        print("✓ コンピュートエンコーダ作成成功")
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setBuffer(seedBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(publicKeyBuffer, offset: 0, index: 1)

        let threadGroupSize = MTLSize(width: min(32, count), height: 1, depth: 1)
        let threadGroups = MTLSize(width: (count + 31) / 32, height: 1, depth: 1)
        print("✓ スレッドグループ設定: \(threadGroups.width)x\(threadGroups.height)x\(threadGroups.depth)")
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        // Add completion handler
        commandBuffer.addCompletedHandler { buffer in
            if let error = buffer.error {
                print("❌ GPU実行エラー: \(error)")
            }
        }
        
        commandBuffer.commit()
        print("✓ コマンドバッファをコミット")
        
        commandBuffer.waitUntilCompleted()
        print("✓ GPU処理完了")

        let publicKeysPtr = publicKeyBuffer.contents().bindMemory(to: UInt8.self, capacity: count * 32)
        var results: [(UInt64, UInt64)] = []
        for i in 0..<count {
            var x: UInt64 = 0
            var y: UInt64 = 0
            for j in 0..<32 {
                if j < 16 {
                    x = (x << 8) | UInt64(publicKeysPtr[i * 32 + j])
                } else {
                    y = (y << 8) | UInt64(publicKeysPtr[i * 32 + j])
                }
            }
            results.append((x, y))
        }
        print("✓ 結果の変換完了 (\(results.count) 個の鍵ペア)")
        return results
    }
}
