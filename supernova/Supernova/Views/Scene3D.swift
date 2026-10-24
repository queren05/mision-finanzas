import SwiftUI
import SceneKit

/// Escena 3D ligera con SceneKit. Se dibuja a 30 fps y solo mientras se ve.
struct BlackHoleView: UIViewRepresentable {
    var active: Bool

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.preferredFramesPerSecond = 30
        v.allowsCameraControl = false
        v.scene = ModelLibrary.blackHoleScene()
        v.isPlaying = active
        v.rendersContinuously = active
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        v.isPlaying = active
        v.rendersContinuously = active
    }

    static func dismantleUIView(_ v: SCNView, coordinator: ()) {
        v.isPlaying = false
        v.scene = nil
    }
}

/// Modelos 3D del juego.
///
/// Para usar modelos de verdad en vez de primitivas, añade al proyecto un archivo `.usdz` o `.scn`
/// con el nombre que se pide (por ejemplo `agujero_negro.usdz`). Sitios con modelos gratuitos y
/// libres de derechos (CC0): Poly Pizza (poly.pizza), Kenney (kenney.nl/assets) y la galería AR de
/// Apple (developer.apple.com/augmented-reality/quick-look). Si el archivo no está, se usa la
/// versión hecha con primitivas, así que el juego funciona igual.
enum ModelLibrary {
    static func load(_ name: String) -> SCNNode? {
        for ext in ["usdz", "scn", "usd"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext),
                  let scene = try? SCNScene(url: url, options: [.checkConsistency: false]) else { continue }
            let node = SCNNode()
            for child in scene.rootNode.childNodes { node.addChildNode(child) }
            return node
        }
        return nil
    }

    static func blackHoleScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.wantsHDR = true
        camera.camera?.bloomIntensity = 1.2
        camera.camera?.bloomThreshold = 0.35
        camera.camera?.bloomBlurRadius = 8
        camera.position = SCNVector3(0, 1.1, 4.6)
        camera.constraints = [SCNLookAtConstraint(target: scene.rootNode)]
        scene.rootNode.addChildNode(camera)

        if let custom = load("agujero_negro") {
            custom.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 20)))
            scene.rootNode.addChildNode(custom)
            return scene
        }

        // horizonte de sucesos
        let hole = SCNNode(geometry: SCNSphere(radius: 0.62))
        let black = SCNMaterial()
        black.lightingModel = .constant
        black.diffuse.contents = UIColor.black
        hole.geometry?.firstMaterial = black
        scene.rootNode.addChildNode(hole)

        // brillo alrededor
        let halo = SCNNode(geometry: SCNSphere(radius: 0.72))
        let haloMat = SCNMaterial()
        haloMat.lightingModel = .constant
        haloMat.diffuse.contents = UIColor(red: 0.85, green: 0.45, blue: 1, alpha: 1)
        haloMat.transparency = 0.25
        haloMat.blendMode = .add
        haloMat.writesToDepthBuffer = false
        halo.geometry?.firstMaterial = haloMat
        scene.rootNode.addChildNode(halo)

        // disco de acreción
        let disk = SCNNode()
        disk.eulerAngles = SCNVector3(0.32, 0, 0.12)
        scene.rootNode.addChildNode(disk)
        let rings: [(CGFloat, CGFloat, UIColor)] = [
            (1.05, 0.16, UIColor(red: 1, green: 0.62, blue: 0.25, alpha: 1)),
            (1.4, 0.08, UIColor(red: 1, green: 0.42, blue: 0.75, alpha: 1)),
            (1.75, 0.035, UIColor(red: 0.6, green: 0.5, blue: 1, alpha: 1)),
        ]
        for (k, r) in rings.enumerated() {
            let ring = SCNNode(geometry: SCNTorus(ringRadius: r.0, pipeRadius: r.1))
            let m = SCNMaterial()
            m.lightingModel = .constant
            m.diffuse.contents = r.2
            m.emission.contents = r.2
            m.blendMode = .add
            m.transparency = 0.9
            ring.geometry?.firstMaterial = m
            ring.scale = SCNVector3(1, 0.12, 1)
            ring.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4 + Double(k) * 3)))
            disk.addChildNode(ring)
        }

        // partículas que caen hacia el centro
        let ps = SCNParticleSystem()
        ps.birthRate = 70
        ps.particleLifeSpan = 2.4
        ps.particleSize = 0.035
        ps.particleColor = UIColor(red: 1, green: 0.8, blue: 0.5, alpha: 1)
        ps.particleColorVariation = SCNVector4(0.2, 0.3, 0.3, 0)
        ps.emitterShape = SCNTorus(ringRadius: 1.6, pipeRadius: 0.05)
        ps.birthLocation = .surface
        ps.particleVelocity = 0.25
        ps.blendMode = .additive
        ps.isAffectedByGravity = false
        disk.addParticleSystem(ps)

        return scene
    }
}
