import Metal

struct SHA3 {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState

    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal デバイスが見つかりません。")
            return nil
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ Metal コマンドキューの作成に失敗しました。")
            return nil
        }
        self.commandQueue = commandQueue

        guard let libraryPath = Bundle.module.path(forResource: "default", ofType: "metallib") else {
            print("❌ Metal ライブラリファイルが見つかりません。")
            return nil
        }
        
        do {
            let library = try device.makeLibrary(filepath: libraryPath)
            guard let function = library.makeFunction(name: "hash_public_key") else {
                print("❌ Metal 関数が見つかりません。")
                return nil
            }
            
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            print("❌ Metal シェーダーのコンパイルに失敗しました：\(error)")
            return nil
        }
    }

    func hashPublicKeys(_ keys: [Data]) -> [Data] {
        let count = keys.count
        let publicKeyBuffer = device.makeBuffer(length: count * 32, options: .storageModeShared)!
        let hashBuffer = device.makeBuffer(length: count * 32, options: .storageModeShared)!

        // 入力データをコピー
        let publicKeysPointer = publicKeyBuffer.contents().assumingMemoryBound(to: UInt8.self)
        for i in 0..<count {
            keys[i].copyBytes(to: publicKeysPointer.advanced(by: i * 32), count: 32)
        }

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setBuffer(publicKeyBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(hashBuffer, offset: 0, index: 1)

        let threadsPerGroup = MTLSize(width: 256, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (count + 255) / 256, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let hashesPointer = hashBuffer.contents().bindMemory(to: UInt8.self, capacity: count * 32)
        return (0..<count).map { i in Data(bytes: hashesPointer.advanced(by: i * 32), count: 32) }
    }
}
