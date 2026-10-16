import SwiftUI
import UniverseModule

struct MissionCardModel: Identifiable, Equatable {
    let mission: Mission

    var id: Mission.ID { mission.id }

    var imageResource: ImageResource {
        mission.flightPlan == .artemisII ? .dstMoon : .dstEarth
    }

    var accentColors: [Color] {
        switch mission.flightPlan {
        case .artemisII: [.indigo, .purple]
        case .starshipFlight14: [.orange, .red]
        case .crew13: [.blue, .cyan]
        }
    }

    func formattedLaunchDate(locale: Locale) -> String {
        mission.launchDate.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: .gmt)
        )
    }
}
