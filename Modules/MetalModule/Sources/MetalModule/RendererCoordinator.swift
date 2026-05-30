//
//  RendererCoordinator.swift
//  MetalModule
//
//  Created by max on 05.05.2026.
//

import UIKit

@MainActor
public final class RendererCoordinator: NSObject, PlanetLabelDelegate {
    var renderer: MetalRenderer?
    weak var resources: MetalModuleResources?
    private var labels: [String: UILabel] = [:]
    var currentSelectedPlanet: String?
    var cameraController: CameraController?

    override init() {}

    func setupLabels(in view: UIView, planetNames: [String]) {
        for name in planetNames {
            let label = UILabel()
            label.text = name
            label.textColor = .white
            label.font = .systemFont(ofSize: 12)
            label.sizeToFit()
            label.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self,
                                             action: #selector(handleLabelTap(_:)))
            label.addGestureRecognizer(tap)
            view.addSubview(label)
            labels[name] = label
        }
    }

    func updatePlanetLabels(_ positions: [String: SIMD2<Float>]) {
        DispatchQueue.main.async {
            for (name, label) in self.labels {
                if let position = positions[name] {
                    label.center = CGPoint(x: CGFloat(position.x),
                                            y: CGFloat(position.y))
                    label.isHidden = false
                } else {
                    label.isHidden = true
                }
            }
        }
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(ofTouch: 0, in: gesture.view)
        print("Touch point\(point)")
    }

    @objc func handleLabelTap(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let name = label.text else { return }
        resources?.followPlanet(named: name)
    }
}
