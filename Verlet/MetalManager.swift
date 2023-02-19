import MetalKit

private let maxFramesInFlight = 3

final class MetalManager {
    static var device: MTLDevice!
    private let metalView: MTKView
    private let defaultLibrary: MTLLibrary
    private let commandQueue: MTLCommandQueue

    private var pipelineState: MTLRenderPipelineState
    private var depthState: MTLDepthStencilState

    private let inFlightSemaphore = DispatchSemaphore(value: maxFramesInFlight)
    var currentBufferIndex: Int = 0

    init?(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let defaultLibrary = device.makeDefaultLibrary() else {
            return nil
        }

        metalView.device = device
        metalView.clearColor = .init(red: 20 / 255.0, green: 26.0 / 255.0, blue: 43.0 / 255.0, alpha: 1.0)
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.depthStencilStorageMode = .memoryless

        Self.device = device
        self.commandQueue = commandQueue
        self.defaultLibrary = defaultLibrary
        self.metalView = metalView

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Simple Pipeline"
        pipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "vertexShader")
        pipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "fragmentShader")
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        pipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float

        self.pipelineState = {
            do {
                return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
            } catch {
                fatalError(error.localizedDescription)
            }
        }()

        let depthStateDesc = MTLDepthStencilDescriptor()
        depthStateDesc.depthCompareFunction = .less
        depthStateDesc.isDepthWriteEnabled = true
        depthState = {
            guard let depthState = device.makeDepthStencilState(descriptor: depthStateDesc) else {
                fatalError("Failed to create depth state")
            }
            return depthState
        }()
    }

    var commandBuffer: MTLCommandBuffer? = nil

    func openFrame() -> Bool {
        inFlightSemaphore.wait()
        assert(commandBuffer == nil)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return false }
        commandBuffer.label = "Main command buffer"
        commandBuffer.addCompletedHandler { [inFlightSemaphore] _ in
            inFlightSemaphore.signal()
        }
        self.commandBuffer = commandBuffer
        currentBufferIndex = (currentBufferIndex + 1) % maxFramesInFlight
        return true
    }

    func closeFrame() {
        guard let commandBuffer else {
            fatalError("Mismatched open/close commandBuffer")
        }
        commandBuffer.commit()
        self.commandBuffer = nil
    }

    var renderEncoder: MTLRenderCommandEncoder? = nil

    func openMainRenderEncoder() -> MTLRenderCommandEncoder? {
        assert(renderEncoder == nil)
        guard let rpd = metalView.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: rpd) else {
            return nil
        }

        self.renderEncoder = renderEncoder
        return renderEncoder
    }

    func closeMainRenderEncoder() {
        renderEncoder?.endEncoding()
        renderEncoder = nil
    }

    func present() {
        if let drawable = metalView.currentDrawable {
            commandBuffer?.present(drawable)
        }
    }

    func setDefaultPipeline(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
    }
}
