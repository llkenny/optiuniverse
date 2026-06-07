import Testing
@testable import BaseModule

@Test func appEnvironmentDefaultsMatchVersionOneLaunchState() {
    let environment = AppEnvironment()

    #expect(environment.username == "Stranger")
    #expect(isHomeScreen(environment.currentScreen))
    #expect(environment.selectedDestinationID == nil)
    #expect(environment.selectedPlanet == nil)
    #expect(environment.location == "Unknown, Solar System, Milky Way")

    environment.selectedPlanet = "Mars"

    #expect(environment.location == "Mars, Solar System, Milky Way")
}

private func isHomeScreen(_ screen: AppEnvironment.Screen) -> Bool {
    if case .home = screen {
        return true
    }

    return false
}
