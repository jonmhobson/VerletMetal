import Foundation
import Metal

struct BufferManager {
    func createBuffer<T>(count: Int, aligned: Bool = false) -> MetalBuffer<T> {
        return MetalBuffer(count: count, aligned: aligned)
    }

    func createBufferGroup<T>(count: Int, aligned: Bool = false) -> MetalBufferGroup<T> {
        return MetalBufferGroup(count: count, aligned: aligned)
    }
}

struct MetalBuffer<T> {
    let buffer: MTLBuffer
    let count: Int
    let stride: Int

    var alignedStride: Int {
        self.stride / MemoryLayout<T>.stride
    }

    init(count: Int, aligned: Bool) {
        self.count = count
        self.stride = aligned ? (MemoryLayout<T>.stride & ~0xFF) + 0x100 : MemoryLayout<T>.stride
        self.buffer = MetalManager.device.makeBuffer(length: stride * count, options: .storageModeShared)!
        self.buffer.label = "\(T.self) x \(count) buffer"
    }

    func bind() -> UnsafeMutablePointer<T> {
        return buffer.contents().bindMemory(to: T.self, capacity: 1)
    }
}

struct MetalBufferGroup<T> {
    let buffers: [MTLBuffer]
    let count: Int
    let stride: Int

    var alignedStride: Int {
        self.stride / MemoryLayout<T>.stride
    }

    init(count: Int, aligned: Bool) {
        self.count = count
        let stride = aligned ? (MemoryLayout<T>.stride & ~0xFF) + 0x100 : MemoryLayout<T>.stride
        self.stride = stride
        self.buffers = (0..<3).map { index in
            let buffer = MetalManager.device.makeBuffer(length: stride * count, options: .storageModeShared)!
            buffer.label = "\(T.self) x \(count) group buffer[\(index)]"
            return buffer
        }
    }

    func bind(index: Int) -> UnsafeMutablePointer<T> {
        assert(index < 3)
        return buffers[index].contents().bindMemory(to: T.self, capacity: 1)
    }
}
