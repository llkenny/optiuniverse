//
//  LegalCreditsView.swift
//  OptiUniverse
//
//  Created by Codex on 16.05.2026.
//

import SwiftUI

struct LegalCreditsView: View {

    private let credits = LegalCreditsCatalog.sections

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Legal & Credits")
                        .font(Typography.screenTitle)
                        .foregroundStyle(OptiColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(credits) { credit in
                        LegalCreditCard(section: credit)
                    }
                }
                .padding()
            }
            .background(OptiColor.screenBackground.ignoresSafeArea())
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

enum LegalCreditsCatalog {
    static let sections: [LegalCreditSection] = [
        LegalCreditSection(
            title: "3D Solar System Model",
            body: """
            "High Resolution Solar system" by pebegou.
            Licensed under Creative Commons Attribution 4.0 International.
            Changes: Converted and optimized for use in OptiUniverse.
            """,
            links: [
                LegalCreditLink(
                    title: "Source",
                    url: URL(string: "https://www.fab.com/listings/f8e5507c-76d2-44f5-97b2-d22c264dc4ab")!
                ),
                LegalCreditLink(
                    title: "License",
                    url: URL(string: "https://creativecommons.org/licenses/by/4.0/")!
                )
            ]
        ),
        LegalCreditSection(
            title: "Milky Way Environment",
            body: """
            "The Milky Way panorama".
            Credit: ESO/S. Brunier.
            Licensed under Creative Commons Attribution 4.0 International.
            Used as the live Metal renderer deep-space environment.
            """,
            links: [
                LegalCreditLink(
                    title: "Source",
                    url: URL(string: "https://www.eso.org/public/images/eso0932a/")!
                ),
                LegalCreditLink(
                    title: "License",
                    url: URL(string: "https://creativecommons.org/licenses/by/4.0/")!
                ),
                LegalCreditLink(
                    title: "ESO Usage Terms",
                    url: URL(string: "https://www.eso.org/public/outreach/copyright/")!
                )
            ]
        ),
        LegalCreditSection(
            title: "Planet Imagery",
            body: """
            Planet imagery is courtesy of NASA, ESA, STScI, JPL, and listed source agencies.
            NASA does not endorse this app.
            """,
            links: [
                LegalCreditLink(
                    title: "NASA Images and Media Guidelines",
                    url: URL(string: "https://www.nasa.gov/nasa-brand-center/images-and-media/")!
                ),
                LegalCreditLink(
                    title: "ESA/Hubble Images",
                    url: URL(string: "https://esahubble.org/images/")!
                )
            ]
        ),
        LegalCreditSection(
            title: "Featured Images",
            body: """
            Selected featured object imagery uses NASA/ESA Hubble source material.
            """,
            links: [
                LegalCreditLink(
                    title: "Mars Hubble Image",
                    url: URL(string: "https://esahubble.org/images/opo0124a/")!
                ),
                LegalCreditLink(
                    title: "Neptune Hubble Image",
                    url: URL(string: "https://esahubble.org/images/opo1622b/")!
                ),
                LegalCreditLink(
                    title: "Saturn Hubble Image",
                    url: URL(string: "https://esahubble.org/images/heic1917a/")!
                )
            ]
        ),
        LegalCreditSection(
            title: "Moon Base Images",
            body: """
            NASA media resources related to the Moon Base.
            """,
            links: [
                LegalCreditLink(
                    title: "Concept for Sustained Lunar Surface Operations at the Moon Base",
                    url: URL(
                        string: "https://www.nasa.gov/image-detail/stmd-exteriorlunarbase-hdlandscapeversion-2026-0521/"
                    )!
                ),
                LegalCreditLink(
                    title: "Lunar South Pole Region",
                    url: URL(string: "https://www.nasa.gov/image-detail/moon-background/")!
                ),
                LegalCreditLink(
                    title: "Concept for Base at the Lunar South Pole",
                    url: URL(string: "https://www.nasa.gov/image-detail/liveenable-im4-craterlogistics-1/")!
                ),
                LegalCreditLink(
                    title: "Concept for Lunar Surface Logistics and Infrastructure",
                    url: URL(
                        string: "https://www.nasa.gov/image-detail/liveenable-im3-sustainabilitylogistics-withastros-3/"
                    )!
                )
            ]
        ),
        LegalCreditSection(
            title: "Destination Thumbnails",
            body: """
            Destination thumbnails use NASA, ESA/Hubble, JPL, STScI, and Wikimedia Commons source material.
            """,
            links: [
                LegalCreditLink(
                    title: "Sun",
                    url: URL(string: "https://science.nasa.gov/photojournal/pulses-from-the-sun/")!
                ),
                LegalCreditLink(
                    title: "Mercury",
                    url: URL(string: "https://science.nasa.gov/photojournal/outgoing-hemisphere/")!
                ),
                LegalCreditLink(
                    title: "Venus",
                    url: URL(string: "https://science.nasa.gov/resource/venus-cloud-tops-viewed-by-hubble/")!
                ),
                LegalCreditLink(
                    title: "Earth",
                    url: URL(string: "https://commons.wikimedia.org/wiki/File:Earth_from_Space.jpg")!
                ),
                LegalCreditLink(
                    title: "Moon",
                    url: URL(string: "https://commons.wikimedia.org/wiki/File:Full_moon.jpeg")!
                ),
                LegalCreditLink(
                    title: "Mars",
                    url: URL(string: "https://esahubble.org/images/opo0124a/")!
                ),
                LegalCreditLink(
                    title: "Jupiter",
                    url: URL(string: "https://esahubble.org/images/heic2017a/")!
                ),
                LegalCreditLink(
                    title: "Saturn",
                    url: URL(string: "https://esahubble.org/images/heic1917a/")!
                ),
                LegalCreditLink(
                    title: "Uranus",
                    url: URL(string: "https://esahubble.org/images/potw1906a/")!
                ),
                LegalCreditLink(
                    title: "Neptune",
                    url: URL(string: "https://esahubble.org/images/opo2059a/")!
                ),
                LegalCreditLink(
                    title: "Pluto",
                    url: URL(string: "https://science.nasa.gov/dwarf-planets/pluto/facts/")!
                )
            ]
        )
    ]
}

private struct LegalCreditCard: View {
    let section: LegalCreditSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(Typography.overlayHeading)
                .foregroundStyle(OptiColor.textPrimary)

            Text(section.body)
                .font(Typography.overlayBody)
                .foregroundStyle(OptiColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.links) { link in
                    Link(destination: link.url) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.system(size: 13, weight: .semibold))
                            Text(link.title)
                                .font(Typography.overlayBody)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(OptiColor.controlSelected)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OptiColor.overlaySurface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .stroke(OptiColor.overlayBorder, lineWidth: 1)
        )
    }
}

struct LegalCreditSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let links: [LegalCreditLink]
}

struct LegalCreditLink: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

#Preview {
    LegalCreditsView()
}
