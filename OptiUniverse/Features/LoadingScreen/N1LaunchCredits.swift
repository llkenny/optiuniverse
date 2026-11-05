import Foundation

extension LegalCreditsCatalog {
    static let n1Launch = LegalCreditSection(
        title: "N1 Launch Photograph",
        body: """
        N1 1M1 test vehicle at Baikonur, 1967.
        Credit: National Reconnaissance Office, via NASA and Wikimedia Commons.
        Listed by Wikimedia Commons as public domain in the United States.
        Changes: AI-assisted photo extraction, base retouching and background reconstruction;
        generated vapor and exhaust; illustrative animation. This is not footage of a historical launch.
        """,
        links: [
            LegalCreditLink(
                title: "Photograph and Usage Information",
                url: URL(string: "https://commons.wikimedia.org/wiki/File:"
                         + "N1_1M1_mockup_on_the_launch_pad_at_the_Baikonur_Cosmodrome_in_late_1967.jpg")!
            ),
            LegalCreditLink(
                title: "NASA Historical Context",
                url: URL(string: "https://www.nasa.gov/history/"
                         + "50-years-ago-soviets-moon-rockets-rollout-to-pad-affects-apollo-plans/")!
            )
        ]
    )
}
