import BaseModule
import Testing

@MainActor
struct AppEnvironmentTests {
    @Test func defaultsMatchVersionOneLaunchState() {
        let environment = AppEnvironment()

        #expect(environment.username == "Stranger")
        #expect(isHomeScreen(environment.currentScreen))
        #expect(environment.selectedDestinationID == nil)
        #expect(environment.selectedPlanet == nil)
        #expect(environment.location == "Unknown, Solar System, Milky Way")

        environment.selectedPlanet = "Mars"

        #expect(environment.location == "Mars, Solar System, Milky Way")
    }
}
