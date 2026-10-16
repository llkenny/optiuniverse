import simd

extension StarshipFlightState {
    func translated(by offset: SIMD3<Double>) -> Self {
        Self(ship: ship.translated(by: offset), booster: booster.translated(by: offset),
             satellites: satellites.map { $0.translated(by: offset) }, status: status,
             shipThrust: shipThrust, boosterThrust: boosterThrust, reentryGlow: reentryGlow,
             boosterVisible: boosterVisible)
    }
}

extension Crew13FlightState {
    func translated(by offset: SIMD3<Double>) -> Self {
        Self(dragon: dragon.translated(by: offset), firstStage: firstStage.translated(by: offset),
             secondStage: secondStage.translated(by: offset), station: station.translated(by: offset),
             firstStageVisible: firstStageVisible, secondStageVisible: secondStageVisible,
             firstStageThrust: firstStageThrust, secondStageThrust: secondStageThrust,
             noseConeOpen: noseConeOpen, status: status)
    }
}
