import RealityKit

extension UniverseSceneCoordinator {
    func playConfiguredAnimations(for descriptor: CelestialAssetDescriptor,
                                  on assetRoot: Entity) {
        // These declared clips animate atmospheric child layers (Clouds / White_Belts /
        // Orange_Belts), not the body frame. Keep them independent of the IAU rotation.
        guard !descriptor.animations.isEmpty else { return }
        let availableAnimations = assetRoot.availableAnimations.reduce(
            into: [String: AnimationResource]()
        ) { animationsByName, animation in
            animationsByName[animation.name] = animationsByName[animation.name] ?? animation
        }
        var controllers: [AnimationPlaybackController] = []
        controllers.reserveCapacity(descriptor.animations.count)
        for configuredAnimation in descriptor.animations {
            let animationOwnerAndResource = availableAnimations[configuredAnimation.name].map {
                (assetRoot, $0)
            } ?? animationResource(named: configuredAnimation.name, in: assetRoot)
            guard let (animationOwner, animation) = animationOwnerAndResource else { continue }
            let playbackAnimation = configuredAnimation.repeats ? animation.repeat() : animation
            controllers.append(animationOwner.playAnimation(playbackAnimation))
        }
        if !controllers.isEmpty {
            animationPlaybackControllers[descriptor.displayName] = controllers
        }
    }

    func resumeConfiguredAnimationsIfNeeded() {
        for (bodyName, descriptor) in bodyDescriptors where !descriptor.animations.isEmpty {
            guard animationPlaybackControllers[bodyName]?.isEmpty != false,
                  let assetRoot = bodyEntities[bodyName]?.visualRoot.children.first else {
                continue
            }
            playConfiguredAnimations(for: descriptor, on: assetRoot)
        }
    }

    func stopAnimations(for bodyName: String) {
        animationPlaybackControllers[bodyName]?.forEach { $0.stop() }
        animationPlaybackControllers[bodyName] = nil
    }

    func stopAllAnimations() {
        animationPlaybackControllers.values.flatMap { $0 }.forEach { $0.stop() }
        animationPlaybackControllers.removeAll()
    }

    private func animationResource(named name: String,
                                   in entity: Entity) -> (Entity, AnimationResource)? {
        if let animationLibrary = entity.components[AnimationLibraryComponent.self] {
            if let animation = animationLibrary.animations[name] {
                return (entity, animation)
            }
            if let animation = animationLibrary.animations.first(where: {
                Self.animationKey($0.key, matches: name)
            })?.value {
                return (entity, animation)
            }
        }
        for child in entity.children {
            if let animation = animationResource(named: name, in: child) {
                return animation
            }
        }
        return nil
    }

    private static func animationKey(_ key: String, matches configuredName: String) -> Bool {
        key.split(separator: "/").last.map(String.init) == configuredName
    }
}
