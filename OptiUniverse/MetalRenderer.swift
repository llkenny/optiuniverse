//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//


// MetalRenderer.swift
import MetalKit

let diameterOfSun: Float = 696_000.0
let diameterOfMercury: Float = 4_879.0
let diameterOfVenus: Float = 12_104.0
let diameterOfEarth: Float = 12_756.0
//let diameterOfMoon: Float = 3_475.0
let diameterOfMars: Float = 6_792.0
let diameterOfJupiter: Float = 142_984.0
let diameterOfSaturn: Float = 120_536.0
let diameterOfUranus: Float = 51_118.0
let diameterOfNeptune: Float = 49_528.0

let diameterFactor: Float = 5e-5

let distanceBetweenSunAndMercury: Float = 5_791_e4
let distanceBetweenSunAndVenus: Float = 10_820_e4
let distanceBetweenSunAndEarth: Float = 14_960_e4
let distanceBetweenSunAndMars: Float = 22_794_e4
let distanceBetweenSunAndJupiter: Float = 77_833_e4
let distanceBetweenSunAndSaturn: Float = 142_672_e4
let distanceBetweenSunAndUranus: Float = 287_099_e4
let distanceBetweenSunAndNeptune: Float = 449_825_e4

let distanceFactor: Float = 1e-9

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var axesPipelineState: MTLRenderPipelineState!
    private var mesh: MTKMesh!
    
    // Solar system data
    private var planets: [Planet] = []
    
    init?(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        super.init()
        
        metalView.device = device
        metalView.delegate = self
//        metalView.colorPixelFormat = .bgra8Unorm_srgb
//        metalView.depthStencilPixelFormat = .depth32Float
        
        setupPipeline()
//        setupAxesPipeline()
        initializeSolarSystem()
    }
    
    private func setupPipeline() {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(sphereWithExtent: [0.01, 0.01, 0.01],
                              segments: [100, 100],
                              inwardNormals: false,
                              geometryType: .triangles,
                              allocator: allocator)
        mesh = try! MTKMesh(mesh: mdlMesh, device: device)
        
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "basic_fragment")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        pipelineDescriptor.vertexDescriptor =
        MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func setupAxesPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "axes_vertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "axes_fragment")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        
        // Important for line rendering:
        pipelineDescriptor.vertexDescriptor = {
            let descriptor = MTLVertexDescriptor()
            
            // Position (x,y,z)
            descriptor.attributes[0].format = .float3
            descriptor.attributes[0].offset = 0
            descriptor.attributes[0].bufferIndex = 0
            
            // Color (r,g,b)
            descriptor.attributes[1].format = .float3
            descriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
            descriptor.attributes[1].bufferIndex = 0
            
            descriptor.layouts[0].stride = MemoryLayout<Float>.stride * 6
            return descriptor
        }()
        
        do {
            axesPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create axes pipeline state: \(error)")
        }
    }
    
    private func initializeSolarSystem() {
        // Create basic solar system models
        // This would be expanded with actual planet data
        let sun = Planet(name: "Sun",
                         radius: diameterOfSun / 2 * diameterFactor,
                         distance: 0,
                         position: .init(x: 0, y: 0, z: 0),
                         color: .white)
        let mercury = Planet(name: "Mercury",
                             radius: diameterOfMercury / 2 * diameterFactor,
                             distance: distanceBetweenSunAndMercury * distanceFactor,
                             position: .init(x: 0, y: 0, z: 0),
                             color: .mercury)
        let venus = Planet(name: "Venus",
                           radius: diameterOfVenus / 2 * diameterFactor,
                           distance: distanceBetweenSunAndVenus * distanceFactor,
                           position: .init(x: 0, y: 0, z: 0),
                           color: .venus)
        let earth = Planet(name: "Earth",
                           radius: diameterOfEarth / 2 * diameterFactor,
                           distance: distanceBetweenSunAndEarth * distanceFactor,
                           position: .init(x: 0.5, y: 0, z: 0),
                           color: .earth)
        let mars = Planet(name: "Mars",
                          radius: diameterOfMars / 2 * diameterFactor,
                          distance: distanceBetweenSunAndMars * distanceFactor,
                          position: .init(x: -0.5, y: 0, z: 0),
                          color: .mars)
        let juptier = Planet(name: "Jupiter",
                             radius: diameterOfJupiter / 2 * diameterFactor,
                             distance: distanceBetweenSunAndJupiter * distanceFactor,
                             position: .init(x: 0, y: 0, z: 0),
                             color: .jupiter)
        let saturn = Planet(name: "Saturn",
                            radius: diameterOfSaturn / 2 * diameterFactor,
                            distance: distanceBetweenSunAndSaturn * distanceFactor,
                            position: .init(x: 0, y: 0, z: 0),
                            color: .saturn)
        let uranus = Planet(name: "Uranus",
                            radius: diameterOfUranus / 2 * diameterFactor,
                            distance: distanceBetweenSunAndUranus * distanceFactor,
                            position: .init(x: 0, y: 0, z: 0),
                            color: .uranus)
        let neptune = Planet(name: "Neptune",
                             radius: diameterOfNeptune / 2 * diameterFactor,
                             distance: distanceBetweenSunAndNeptune * distanceFactor,
                             position: .init(x: 0, y: 0, z: 0),
                             color: .neptune)
        
        planets = [sun, mercury, venus, earth, mars, juptier, saturn, uranus, neptune]
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
//        renderAxes(with: renderEncoder)
        
//         Update and render planets
        for planet in planets {
            renderPlanet(planet, with: renderEncoder)
        }
        
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
    
    private func renderAxes(with renderEncoder: MTLRenderCommandEncoder) {
        // Define axis vertices (position + color)
        // Format: [x, y, z, r, g, b]
        let vertices: [Float] = [
            // X axis (red)
            0, 0, 0,   1, 0, 0,  // Start point
            10, 0, 0,  1, 0, 0,  // End point
            
            // Y axis (green)
            0, 0, 0,   0, 1, 0,  // Start point
            0, 10, 0,  0, 1, 0,  // End point
            
            // Z axis (blue)
            0, 0, 0,   0, 0, 1,  // Start point
            0, 0, 10,  0, 0, 1   // End point
        ]
        
        // Create vertex buffer
        let vertexBuffer = device.makeBuffer(bytes: vertices,
                                             length: vertices.count * MemoryLayout<Float>.stride,
                                             options: [])
        
        // Set pipeline state for lines (make sure you have one)
        renderEncoder.setRenderPipelineState(axesPipelineState)
        
        // Set vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Set transformation matrix
        var matrix = matrix_identity_float4x4
        renderEncoder.setVertexBytes(&matrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 1)
        
        // Draw as lines (not triangles)
        renderEncoder.drawPrimitives(type: .line,
                                     vertexStart: 0,
                                     vertexCount: 6) // 2 points per line × 3 axes = 6 vertices
    }
    
    var delta: Float = 0.01
    var x: Float = 0
    var y: Float = 0
    var angle: Float = 0
    var isRight = true
    var isDown = true
    var limits: [Float] = [2, 1.5, -2, -2.3]
    var f: Float = -0.5
    var time: Float = 0
    var deltaAngle: Float = .pi / 1800
    private func renderPlanet(_ planet: Planet, with renderEncoder: MTLRenderCommandEncoder) {
        // Create vertices for a simple triangle (replace with sphere data)
//        let vertices: [Float] = [
//            // Position         // Color
//            -0.5, 0, 0,     planet.color.x, planet.color.y, planet.color.z,
//            0.5, 0, 0,   planet.color.x, planet.color.y, planet.color.z,
//            0, 0.5, 0,    planet.color.x, planet.color.y, planet.color.z
//        ]
        
//        let vertices: [Float] = [
//            // Position
//            -0.5, // x 1
//             -0.5, // y 1
//             0, // z 1
//             1, // ??
//             1, // ??
//             1, // ??
//             -0.5, // ?? z?
//             -0.5, // ?? z?
//             0, 1 // x, y 2
//        ]
//        f += delta
//        
//        let vertexBuffer = device.makeBuffer(bytes: vertices,
//                                             length: vertices.count * MemoryLayout<Float>.stride,
//                                             options: [])
//        
//        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
//        
//        // Simple uniform matrix (replace with proper transformation)
        var matrix = matrix_identity_float4x4
        + float4x4(
            [planet.radius * 2, 0, 0, 0],
            [0, planet.radius * 2, 0, 0],
            [0, 0, planet.radius * 2, 0],
            [0, 0, 0, 1]
        )
        + float4x4(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, planet.distance, 0, 1]
        )
        // Предположим, у нас есть точка A(x, y, z) и мы хотим повернуть её вокруг точки C(cx, cy, cz) на угол θ вокруг оси z.
        // Смещаем точку A: A'(x', y', z') = (x - cx, y - cy, z - cz).
        // Применяем матрицу вращения вокруг оси z:
        let rotationByPoint = float4x4.makeRotationZ(time * deltaAngle) * SIMD4(x: 0, y: -planet.distance, z: 0, w: 1)
        matrix += float4x4(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [rotationByPoint.x, rotationByPoint.y, 0, 1]
        )
        time += 1
        renderEncoder.setVertexBytes(&matrix,
                               length: MemoryLayout<float4x4>.stride,
                               index: 1)
//        
//        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        
        guard let submesh = mesh.submeshes.first else {
            fatalError()
        }
        
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: submesh.indexCount,
            indexType: submesh.indexType,
            indexBuffer: submesh.indexBuffer.buffer,
            indexBufferOffset: 0)
    }
}

struct Planet {
    let name: String
    let radius: Float
    let distance: Float
    let position: SIMD3<Float>
    let color: SIMD3<Float>
}
