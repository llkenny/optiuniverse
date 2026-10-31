import BaseModule
import SwiftUI
import XCTest
@testable import OptiUniverse

@MainActor
final class ObjectInfoLayoutTests: XCTestCase {
    func testPlanetContentFitsPortraitAndSidePanelWidthsWithoutHorizontalOverflow() throws {
        for name in ["Mars", "Venus", "Jupiter"] {
            let entity = try makeEntity(named: name)
            for width in [CGFloat(320), 350, 375, 380, 393, 402] {
                let image = try render(entity, width: width)
                XCTAssertEqual(image.size.width, width, accuracy: 0.5)
                XCTAssertGreaterThan(image.size.height, 400)
                XCTAssertLessThan(image.size.height, 700)
                attach(image, name: "\(name)-\(Int(width))")
            }
        }
    }

    func testAccessibilityAndImageContentRetainTheirNaturalHeight() throws {
        let entity = try makeEntity(named: "Jupiter")
        let normal = try render(entity, width: 393)
        let accessible = try render(entity, width: 393, textSize: .accessibility3)
        XCTAssertEqual(accessible.size.width, 393, accuracy: 0.5)
        XCTAssertGreaterThan(accessible.size.height, normal.size.height)
        attach(accessible, name: "Jupiter-accessibility")

        let base = try render(makeEntity(named: "Moon Base"), width: 320)
        XCTAssertEqual(base.size.width, 320, accuracy: 0.5)
        XCTAssertGreaterThan(base.size.height, 200)
        attach(base, name: "Moon-Base-320")
    }

    func testRouteIsOnlyIncludedForNavigableObjects() throws {
        let navigable = try makeEntity(named: "Jupiter")
        let nonNavigable = ObjectInfoViewEntity(
            id: navigable.id, imageName: nil, title: navigable.title, subtitle: navigable.subtitle,
            description: navigable.description, details: navigable.details,
            navigationButtonTitle: navigable.navigationButtonTitle, isNavigable: false,
            orbitInfo: navigable.orbitInfo, navigationButtonAction: {}
        )
        let withRoute = try render(navigable, width: 393)
        let withoutRoute = try render(nonNavigable, width: 393)
        XCTAssertGreaterThanOrEqual(withRoute.size.height - withoutRoute.size.height, 44)
    }

    private func render(_ entity: ObjectInfoViewEntity, width: CGFloat,
                        textSize: DynamicTypeSize = .large) throws -> UIImage {
        let renderer = ImageRenderer(content: ObjectInfoView(entity: entity, availableWidth: width)
            .environment(\.dynamicTypeSize, textSize)
            .environment(\.colorScheme, .dark)
            .background(.black))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return try XCTUnwrap(renderer.uiImage)
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeEntity(named name: String) throws -> ObjectInfoViewEntity {
        let destinations: [DestinationObject] = try loadMainBundleJSON(named: "DestinationObjects")
        let destination = try XCTUnwrap(destinations.first { $0.title == name })
        return ObjectInfoViewEntity(
            id: destination.id, imageName: destination.infoImageName,
            title: destination.title, subtitle: destination.subtitle, description: destination.description,
            details: destination.details.map {
                ObjectInfoDetailCardEntity(title: $0.title, value: $0.value, dimension: $0.dimension)
            },
            navigationButtonTitle: "🎯 Route", isNavigable: destination.isNavigable,
            orbitInfo: destination.orbitInfo.map {
                ObjectInfoOrbitView.Model(description: $0.description,
                                          properties: [.axis: $0.properties.axis,
                                                       .eccentricity: $0.properties.eccentricity,
                                                       .inclination: $0.properties.inclination])
            }, navigationButtonAction: {}
        )
    }
}
