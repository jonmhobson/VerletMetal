import Foundation
import MetalKit

let worldSize: Float = 800.0

struct Vertex {
    let position: SIMD2<Float>
    let uvs: SIMD2<Float>
    let size: Float
}

let finalPositions = {
    let path = Bundle.main.path(forResource: "positions", ofType: "txt")
    let string = try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
    let positions = string.split(separator: "\n")

    return positions.map { string in
        let parts = string.split(separator: ", ")
        assert(parts.count == 2)
        let x = Float(parts[0])!
        let y = Float(parts[1])!
        return SIMD2<Float>(x, y)
    }
}()

struct VerletObject {
    init(num: Int) {
        let t = Float(num) / 30.0
        positionCurrent = [sinf(t) * worldSize, cosf(t) * worldSize]

        positionOld = positionCurrent
        acceleration = .zero
        size = (5.0 + Float(((num * 6529) % 359) % 25)) * 2.1

        let finalPos = finalPositions[num]

        uvs = finalPos
    }

    var positionCurrent: SIMD2<Float>
    var positionOld: SIMD2<Float>
    var acceleration: SIMD2<Float>
    var uvs: SIMD2<Float>
    var size: Float

    mutating func update(dt: Float) {
        let velocity = positionCurrent - positionOld
        positionOld = positionCurrent
        positionCurrent += velocity + acceleration * dt * dt
        acceleration = .zero
    }
}

final class Renderer: NSObject {
    private let metalManager: MetalManager
    private let bufferManager: BufferManager

    private let pointBuffer: MetalBufferGroup<Vertex>

    private var viewportSize: vector_uint2 = [0, 0]
    private let texture: MTLTexture

    private var objects: [VerletObject] = [
    ]

    init(metalView: MTKView) {
        self.metalManager = MetalManager(metalView: metalView)!
        self.bufferManager = BufferManager()
        self.pointBuffer = bufferManager.createBufferGroup(count: 1000000)
        self.texture = TextureManager.texture(filename: "monkey")!
        super.init()
        metalView.delegate = self
    }

    var frame = 0
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = [UInt32(size.width), UInt32(size.height)]
    }

    private func updateObjects() {
        if frame % 1 == 0 && objects.count < 1500 {
            objects.append(.init(num: objects.count))
        }

        if frame == 1700 {
            for obj in objects {
                print("\(obj.positionCurrent.x), \(obj.positionCurrent.y)")
            }
        }

        frame += 1

        if frame >= 1700 { return }

        let subSteps = 8

        let timeScale = 1.0 - min(max(Float(frame - 1500) / 20.0, 0.0), 1.0)

        let subDt: Float = (1.0 / (Float(60.0) * Float(subSteps))) * timeScale

        for _ in 0..<subSteps {

            // Apply gravity
            for i in 0..<objects.count {
                objects[i].acceleration += [0, -2000];
            }

            // Update positions
            for i in 0..<objects.count {
                objects[i].update(dt: subDt)
            }

            // Solve collisions
            for i in 0..<objects.count {
                for j in i+1..<objects.count {
                    let collisionAxis = objects[i].positionCurrent - objects[j].positionCurrent
                    let dist = simd_length(collisionAxis)
                    let radii = objects[i].size * 0.5 + objects[j].size * 0.5
                    if dist < radii {
                        let n = collisionAxis / dist
                        let delta = radii - dist
                        objects[i].positionCurrent += 0.5 * delta * n
                        objects[j].positionCurrent -= 0.5 * delta * n
                    }
                }
            }

            // Apply constraints
            for i in 0..<objects.count {
                let dist = simd_length(objects[i].positionCurrent)

                if dist > (worldSize - objects[i].size * 0.5) {
                    let n = -objects[i].positionCurrent / dist
                    objects[i].positionCurrent += n * (dist - (worldSize - objects[i].size * 0.5))
                }
            }
        }
    }

    private func updateState() {
        let points = pointBuffer.bind(index: metalManager.currentBufferIndex)
        let sizeModifier = 1.0 + min(0.5, max(0.0, Float(frame - 1550) / 200.0))

        for i in 0..<objects.count {

            points[i] = Vertex(position: objects[i].positionCurrent, uvs: objects[i].uvs, size: objects[i].size * sizeModifier)
        }
    }

    func draw(in view: MTKView) {
        guard metalManager.openFrame() else { return }

        updateObjects()

        if let renderEncoder = metalManager.openMainRenderEncoder() {
            updateState()

            metalManager.setDefaultPipeline(renderEncoder: renderEncoder)

            renderEncoder.setVertexBuffer(pointBuffer.buffers[metalManager.currentBufferIndex], offset: 0, index: 0)
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)

            renderEncoder.setFragmentTexture(texture, index: 0)

            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: objects.count)

            metalManager.closeMainRenderEncoder()
            metalManager.present()
        }

        metalManager.closeFrame()
    }
}
