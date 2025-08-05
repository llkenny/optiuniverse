//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//


// MetalRenderer.swift
import MetalKit

let diameterOfSun: Float = 1_392_700
let diameterOfMercury: Float = 4_879.4
let diameterOfVenus: Float = 12_104
let diameterOfEarth: Float = 12_756
//let diameterOfMoon: Float = 3_475.0
let diameterOfMars: Float = 6_792
let diameterOfJupiter: Float = 139_820
let diameterOfSaturn: Float = 116_460
let diameterOfUranus: Float = 50_724
let diameterOfNeptune: Float = 49_244

let diameterFactor: Float = 1e-5

let distanceBetweenSunAndMercury: Double = 57_910_006
let distanceBetweenSunAndVenus: Double = 108_199_995
let distanceBetweenSunAndEarth: Double = 149_599_951
let distanceBetweenSunAndMars: Double = 227_939_920
let distanceBetweenSunAndJupiter: Double = 778_330_257
let distanceBetweenSunAndSaturn: Double = 1_429_400_028
let distanceBetweenSunAndUranus: Double = 2_870_989_228
let distanceBetweenSunAndNeptune: Double = 4_504_299_579

let distanceFactor: Double = 2e-10

//Planet    Orbital velocity
//Mercury    47.9 km/s (29.8 mi/s)
//Venus    35.0 km/s (21.7 mi/s)
//Earth    29.8 km/s (18.5 mi/s)
//Mars    24.1 km/s (15.0 mi/s)
//Jupiter    13.1 km/s (8.1 mi/s)
//Saturn    9.7 km/s (6.0 mi/s)
//Uranus    6.8 km/s (4.2 mi/s)
//Neptune    5.4 km/s (3.4 mi/s)
let mercuryOrbitSpeed: Float = 47.9
let venusOrbitSpeed: Float = 35.0
let earthOrbitSpeed: Float = 29.8
let marsOrbitSpeed: Float = 24.1
let jupiterOrbitSpeed: Float = 13.1
let saturnOrbitSpeed: Float = 9.7
let uranusOrbitSpeed: Float = 6.8
let neptuneOrbitSpeed: Float = 5.4

let orbitSpeedMultiplier: Float = 1e-3

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var axesPipelineState: MTLRenderPipelineState!
    private var mesh: MTKMesh!
    private var texture: MTLTexture!
    private var samplerState: MTLSamplerState!
    
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
        setupAxesPipeline()
        initializeSolarSystem()
    }
    
    private func setupPipeline() {
//        let allocator = MTKMeshBufferAllocator(device: device)
//        let mdlMesh = MDLMesh(sphereWithExtent: [0.01, 0.01, 0.01],
//                              segments: [100, 100],
//                              inwardNormals: false,
//                              geometryType: .triangles,
//                              allocator: allocator)
//        mesh = try! MTKMesh(mesh: mdlMesh, device: device)
        
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        // Vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        
        // Position (attribute 0)
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // Normal (attribute 1)
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // Texture coordinates (attribute 2)
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        // Layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 8
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        // Create sampler state
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    func createTexturedSphere(radius: Float, textureName: String) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        
        // Create sphere with explicit texture coordinate generation
        let mdlMesh = MDLMesh(
            sphereWithExtent: [0.1, 0.1, 0.1], // TODO: radius, radius, radius
            segments: [100, 100],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: allocator
        )
        
        // Generate texture coordinates - NEW CORRECT APPROACH
        mdlMesh.addUnwrappedTextureCoordinates(forAttributeNamed: MDLVertexAttributeTextureCoordinate)
        
        // TODO: Load texture here for optimization
        // Load texture
//        let textureLoader = MTKTextureLoader(device: device)
//        let textureOptions: [MTKTextureLoader.Option : Any] = [
//            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
//            .textureStorageMode: MTLStorageMode.private.rawValue,
//            .origin: MTKTextureLoader.Origin.bottomLeft.rawValue
//        ]
//        
//        texture = try! textureLoader.newTexture(
//            name: textureName,
//            scaleFactor: 1.0,
//            bundle: nil,
//            options: textureOptions
//        )
        
        // Create material and assign texture
        let textureURL = Bundle.main.url(forResource: textureName, withExtension: "png")!

        let material = MDLMaterial()
        let property = MDLMaterialProperty(
            name: "baseColor",
            semantic: .baseColor,
            url: textureURL
        )
        material.setProperty(property)
        
        // Assign material to submeshes
        for submesh in mdlMesh.submeshes! {
            if let submesh = submesh as? MDLSubmesh {
                submesh.material = material
            }
        }
        
        return mdlMesh
    }
    
//    import ModelIO
//    import MetalKit
//    
//    // Assuming you have an MDLMesh loaded, e.g., from an asset file
//    guard let assetURL = Bundle.main.url(forResource: "myModel", withExtension: "obj") else { return }
//    let asset = MDLAsset(url: assetURL)
//    guard let mesh = asset.object(at: 0) as? MDLMesh else { return }
//    
//    // 1. Create an MDLMaterialProperty for the base color texture
//    guard let textureURL = Bundle.main.url(forResource: "myTexture", withExtension: "png") else { return }
//    let baseColorTextureProperty = MDLMaterialProperty(name: "baseColorTexture", semantic: .baseColor, url: textureURL)
//    
//    // 2. Create an MDLMaterial and set the texture property
//    let material = MDLMaterial(name: "texturedMaterial", scatteringFunction: MDLScatteringFunction())
//    material.setProperty(baseColorTextureProperty)
//    
//    // 3. Apply the material to the submeshes of your MDLMesh
//    if let submeshes = mesh.submeshes as? [MDLSubmesh] {
//        for submesh in submeshes {
//            submesh.material = material
//        }
//    }
//        
//        // Now, when you render this MDLMesh using Metal, the texture will be applied
//        // (assuming your Metal rendering pipeline is set up to handle MDLMaterial properties and textures).

    
    private func setupAxesPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "axes_vertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "axes_fragment")
//        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
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
                         orbitSpeed: 0,
                         position: .init(x: 0, y: 0, z: 0),
                         color: .white,
                         textureName: "sun")
        let mercury = Planet(name: "Mercury",
                             radius: diameterOfMercury / 2 * diameterFactor,
                             distance: Float(distanceBetweenSunAndMercury * distanceFactor),
                             orbitSpeed: mercuryOrbitSpeed,
                             position: .init(x: 0, y: 0, z: 0),
                             color: .mercury,
                             textureName: "mercury")
        let venus = Planet(name: "Venus",
                           radius: diameterOfVenus / 2 * diameterFactor,
                           distance: Float(distanceBetweenSunAndVenus * distanceFactor),
                           orbitSpeed: venusOrbitSpeed,
                           position: .init(x: 0, y: 0, z: 0),
                           color: .venus,
                           textureName: "venus")
        let earth = Planet(name: "Earth",
                           radius: diameterOfEarth / 2 * diameterFactor,
                           distance: Float(distanceBetweenSunAndEarth * distanceFactor),
                           orbitSpeed: earthOrbitSpeed,
                           position: .init(x: 0.5, y: 0, z: 0),
                           color: .earth,
                           textureName: "earth")
        let mars = Planet(name: "Mars",
                          radius: diameterOfMars / 2 * diameterFactor,
                          distance: Float(distanceBetweenSunAndMars * distanceFactor),
                          orbitSpeed: marsOrbitSpeed,
                          position: .init(x: -0.5, y: 0, z: 0),
                          color: .mars,
                          textureName: "mars")
        let juptier = Planet(name: "Jupiter",
                             radius: diameterOfJupiter / 2 * diameterFactor,
                             distance: Float(distanceBetweenSunAndJupiter * distanceFactor),
                             orbitSpeed: jupiterOrbitSpeed,
                             position: .init(x: 0, y: 0, z: 0),
                             color: .jupiter,
                             textureName: "jupiter")
        let saturn = Planet(name: "Saturn",
                            radius: diameterOfSaturn / 2 * diameterFactor,
                            distance: Float(distanceBetweenSunAndSaturn * distanceFactor),
                            orbitSpeed: saturnOrbitSpeed,
                            position: .init(x: 0, y: 0, z: 0),
                            color: .saturn,
                            textureName: "saturn")
        let uranus = Planet(name: "Uranus",
                            radius: diameterOfUranus / 2 * diameterFactor,
                            distance: Float(distanceBetweenSunAndUranus * distanceFactor),
                            orbitSpeed: uranusOrbitSpeed,
                            position: .init(x: 0, y: 0, z: 0),
                            color: .uranus,
                            textureName: "uranus")
        let neptune = Planet(name: "Neptune",
                             radius: diameterOfNeptune / 2 * diameterFactor,
                             distance: Float(distanceBetweenSunAndNeptune * distanceFactor),
                             orbitSpeed: neptuneOrbitSpeed,
                             position: .init(x: 0, y: 0, z: 0),
                             color: .neptune,
                             textureName: "neptune")
        
        planets = [sun, mercury, venus, earth, mars, juptier, saturn, uranus, neptune]
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes
    }
    
    var time: Float = 0

    

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        // Update and render planets
        for planet in planets {
            renderPlanet(planet, with: renderEncoder, time: time)
        }
        time += 1
        
        // TODO:
        
//        // 2. Adding moons with secondary orbits
//        func renderMoon(planetPosition: SIMD3<Float>, ...) {
//            // Similar to planets but relative to parent planet
//        }
//        
//        // 3. Tilted orbits (solar system plane)
//        let tiltMatrix = float4x4.makeRotationX(0.1) // ~5.7° tilt
//        modelMatrix = tiltMatrix * rotationMatrix * translationMatrix
        
        // Render axes
        renderEncoder.setRenderPipelineState(axesPipelineState)
        renderAxes(with: renderEncoder)
        
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
                                             options: [])!
        
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
    
    
    // TODO: Make orbit radius SIM3
    var delta: Float = 0.01
    var x: Float = 0
    var y: Float = 0
    var angle: Float = 0
    var isRight = true
    var isDown = true
    var limits: [Float] = [2, 1.5, -2, -2.3]
    var f: Float = -0.5
    let deltaAngle: Float = .pi / 1800
    private var planetMeshes: [String: MDLMesh] = [:]
    var cachedTextures: [String: Textures] = [:]
    private func renderPlanet(_ planet: Planet,
                              with renderEncoder: MTLRenderCommandEncoder,
                              time: Float) {
        
        // Get or create mesh
        if planetMeshes[planet.textureName] == nil {
            planetMeshes[planet.textureName] = createTexturedSphere(
                radius: planet.radius,
                textureName: planet.textureName
            )
        }
        guard let mesh = planetMeshes[planet.textureName] else { return }
        
        // 1. Create scaling matrix
        let scaleMatrix = float4x4.makeScale([planet.radius, planet.radius, planet.radius])
        
        // 2. Create translation to orbit distance
        var modelMatrix = float4x4.makeTranslation([planet.distance, 0, 0])
        
        // 3. Apply rotation around sun
        let angle = time * planet.orbitSpeed * orbitSpeedMultiplier
        modelMatrix = float4x4.makeRotationZ(angle) * modelMatrix
        
        // 4. Combine with scaling (scale first, then rotate, then translate)
        modelMatrix = modelMatrix * scaleMatrix
        
        // TODO:
        // Combine with view and projection matrices
//        let mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        // 5. Create MVP matrix
        var mvpMatrix = modelMatrix
        
        // TODO:
        // Elliptical orbit example
//        let eccentricity: Float = 0.1 // 0 for circular
//        let ellipticalDistance = distance * (1 - eccentricity * eccentricity) / (1 + eccentricity * cos(angle))
        
//        // Set texture
        if cachedTextures[planet.textureName] == nil {
            let submesh = mesh.submeshes![0] as! MDLSubmesh
            let material = submesh.material!
            //        let baseColor = material?.property(with: MDLMaterialSemantic.baseColor)!
            //        let texture = baseColor!.textureSamplerValue?.texture!
            //        renderEncoder.setFragmentTexture(texture as! MTLTexture, index: 0)
            let texture = Textures(material: material, device: device)
            cachedTextures[planet.textureName] = texture
        }
        let texture = cachedTextures[planet.textureName]!
        
        let mtkMesh = try! MTKMesh(mesh: mesh, device: device)
            
        // TODO:
//        let angle = time * planet.orbitSpeed
//        var modelMatrix = float4x4.makeTranslation([planet.distance, 0, 0])
//        modelMatrix = float4x4.makeRotationZ(angle) * modelMatrix
//        let mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        // Set buffers
        
        renderEncoder.setVertexBytes(&mvpMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 1)
        renderEncoder.setVertexBytes(&modelMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 2)
        
        renderEncoder.setVertexBuffer(mtkMesh.vertexBuffers[0].buffer, offset: 0, index: 0)
//        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentTexture(texture.baseColor!, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        guard let submesh = mtkMesh.submeshes.first else {
            fatalError()
        }
        
        // Draw
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: submesh.indexCount,
            indexType: submesh.indexType,
            indexBuffer: submesh.indexBuffer.buffer,
            indexBufferOffset: submesh.indexBuffer.offset
        )
    }
}

struct Planet {
    let name: String
    let radius: Float
    let distance: Float// Orbital radius
    let orbitSpeed: Float     // Rotation speed multiplier
    let position: SIMD3<Float>
    let color: SIMD3<Float>
    let tilt: Float = 0       // Optional axial tilt}
    let textureName: String
    var mesh: MTKMesh?
}

struct Textures {
    var baseColor: MTLTexture?
}

extension Textures {
    init(material: MDLMaterial?, device: MTLDevice) {
        func property(with semantic: MDLMaterialSemantic)
        -> MTLTexture? {
            guard let property = material?.property(with: semantic),
                  let fileUrl = property.urlValue,
                  let texture =
                    try? loadTexture(url: fileUrl, device: device)
            else { return nil }
            return texture
        }
        baseColor = property(with: MDLMaterialSemantic.baseColor)
    }
    
    func loadTexture(url: URL, device: MTLDevice) throws -> MTLTexture? {
        // 1
        let textureLoader = MTKTextureLoader(device: device)
        
        // 2
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] =
        [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        let texture =
        try textureLoader.newTexture(URL: url,
                                     options: textureLoaderOptions)
        print("loaded texture: \(url.lastPathComponent)")
        return texture
    }
}
