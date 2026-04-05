import Foundation
import CoreLocation

// MARK: - Journey Milestone

struct JourneyMilestone: Identifiable, Codable {
    let id: String
    let name: String
    let distanceFromStartKm: Double
    let funFact: String
    let icon: String
    let coordinate: CodableCoordinate
    var isReached: Bool
    var reachedDate: Date?

    init(id: String = UUID().uuidString, name: String, distanceFromStartKm: Double, funFact: String, icon: String, latitude: Double, longitude: Double, isReached: Bool = false, reachedDate: Date? = nil) {
        self.id = id
        self.name = name
        self.distanceFromStartKm = distanceFromStartKm
        self.funFact = funFact
        self.icon = icon
        self.coordinate = CodableCoordinate(latitude: latitude, longitude: longitude)
        self.isReached = isReached
        self.reachedDate = reachedDate
    }
}

struct CodableCoordinate: Codable {
    let latitude: Double
    let longitude: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Virtual Journey

struct VirtualJourney: Identifiable, Codable {
    let id: String
    let name: String
    let totalDistanceKm: Double
    var milestones: [JourneyMilestone]
    var distanceCoveredKm: Double
    var isCompleted: Bool

    var progress: Double {
        min(distanceCoveredKm / totalDistanceKm, 1.0)
    }

    var nextMilestone: JourneyMilestone? {
        milestones.first { !$0.isReached }
    }

    var distanceToNextMilestone: Double? {
        guard let next = nextMilestone else { return nil }
        return max(next.distanceFromStartKm - distanceCoveredKm, 0)
    }

    var reachedMilestones: [JourneyMilestone] {
        milestones.filter(\.isReached)
    }

    mutating func addDistance(_ km: Double) -> [JourneyMilestone] {
        distanceCoveredKm += km
        var newlyReached: [JourneyMilestone] = []

        for i in milestones.indices {
            if !milestones[i].isReached && distanceCoveredKm >= milestones[i].distanceFromStartKm {
                milestones[i].isReached = true
                milestones[i].reachedDate = .now
                newlyReached.append(milestones[i])
            }
        }

        if distanceCoveredKm >= totalDistanceKm {
            isCompleted = true
        }

        return newlyReached
    }
}

// MARK: - Journey Templates

enum JourneyTemplate: String, CaseIterable, Identifiable {
    case nyToLA = "ny_to_la"
    case pacificCoast = "pacific_coast"
    case route66 = "route_66"
    case appalachianTrail = "appalachian_trail"
    case aroundTheWorld = "around_the_world"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nyToLA: "New York → Los Angeles"
        case .pacificCoast: "Pacific Coast Highway"
        case .route66: "Route 66"
        case .appalachianTrail: "Appalachian Trail"
        case .aroundTheWorld: "Around the World"
        }
    }

    var difficultyLabel: String {
        switch self {
        case .nyToLA: "Starter"
        case .pacificCoast: "Intermediate"
        case .route66: "Advanced"
        case .appalachianTrail: "Challenge"
        case .aroundTheWorld: "Ultimate"
        }
    }

    var totalDistanceKm: Double {
        switch self {
        case .nyToLA: 4_500
        case .pacificCoast: 2_000
        case .route66: 3_940
        case .appalachianTrail: 3_500
        case .aroundTheWorld: 40_075
        }
    }

    func createJourney() -> VirtualJourney {
        VirtualJourney(
            id: rawValue,
            name: displayName,
            totalDistanceKm: totalDistanceKm,
            milestones: createMilestones(),
            distanceCoveredKm: 0,
            isCompleted: false
        )
    }

    private func createMilestones() -> [JourneyMilestone] {
        switch self {
        case .nyToLA:
            return [
                JourneyMilestone(name: "Philadelphia", distanceFromStartKm: 150, funFact: "Home of the first US zoo, opened in 1874.", icon: "building.columns.fill", latitude: 39.9526, longitude: -75.1652),
                JourneyMilestone(name: "Pittsburgh", distanceFromStartKm: 500, funFact: "Has more bridges than any other city in the world — 446!", icon: "arrow.triangle.branch", latitude: 40.4406, longitude: -79.9959),
                JourneyMilestone(name: "Indianapolis", distanceFromStartKm: 1_100, funFact: "Hosts the largest single-day sporting event on Earth.", icon: "flag.checkered", latitude: 39.7684, longitude: -86.1581),
                JourneyMilestone(name: "St. Louis", distanceFromStartKm: 1_500, funFact: "The Gateway Arch is exactly as wide as it is tall — 630 feet.", icon: "archway", latitude: 38.6270, longitude: -90.1994),
                JourneyMilestone(name: "Oklahoma City", distanceFromStartKm: 2_100, funFact: "The State Capitol is the only one with an oil well beneath it.", icon: "drop.fill", latitude: 35.4676, longitude: -97.5164),
                JourneyMilestone(name: "Albuquerque", distanceFromStartKm: 2_900, funFact: "Hosts the world's largest hot air balloon festival.", icon: "balloon.fill", latitude: 35.0844, longitude: -106.6504),
                JourneyMilestone(name: "Flagstaff", distanceFromStartKm: 3_500, funFact: "First city named an International Dark Sky City.", icon: "moon.stars.fill", latitude: 35.1983, longitude: -111.6513),
                JourneyMilestone(name: "Los Angeles", distanceFromStartKm: 4_500, funFact: "The Hollywood Sign originally read 'Hollywoodland' in 1923.", icon: "star.fill", latitude: 34.0522, longitude: -118.2437),
            ]
        case .pacificCoast:
            return [
                JourneyMilestone(name: "Portland", distanceFromStartKm: 280, funFact: "Has more breweries per capita than any city in the world.", icon: "mug.fill", latitude: 45.5152, longitude: -122.6784),
                JourneyMilestone(name: "Eugene", distanceFromStartKm: 460, funFact: "Known as 'Track Town, USA' — birthplace of Nike.", icon: "figure.run", latitude: 44.0521, longitude: -123.0868),
                JourneyMilestone(name: "Crescent City", distanceFromStartKm: 700, funFact: "Gateway to the tallest trees on Earth — the coast redwoods.", icon: "tree.fill", latitude: 41.7558, longitude: -124.2026),
                JourneyMilestone(name: "San Francisco", distanceFromStartKm: 1_050, funFact: "The Golden Gate Bridge's color is officially 'International Orange'.", icon: "bridge", latitude: 37.7749, longitude: -122.4194),
                JourneyMilestone(name: "Big Sur", distanceFromStartKm: 1_250, funFact: "One of only two places in the world where mountains over 1,000m meet the ocean.", icon: "mountain.2.fill", latitude: 36.2704, longitude: -121.8081),
                JourneyMilestone(name: "Santa Barbara", distanceFromStartKm: 1_600, funFact: "Called the 'American Riviera' for its Mediterranean climate.", icon: "sun.max.fill", latitude: 34.4208, longitude: -119.6982),
                JourneyMilestone(name: "San Diego", distanceFromStartKm: 2_000, funFact: "Home to the world's most visited zoo with over 4 million visitors a year.", icon: "pawprint.fill", latitude: 32.7157, longitude: -117.1611),
            ]
        case .route66:
            return [
                JourneyMilestone(name: "Springfield, IL", distanceFromStartKm: 320, funFact: "Abraham Lincoln lived here for 24 years before becoming President.", icon: "building.columns.fill", latitude: 39.7817, longitude: -89.6501),
                JourneyMilestone(name: "St. Louis", distanceFromStartKm: 480, funFact: "The first ice cream cone was served here at the 1904 World's Fair.", icon: "cone.fill", latitude: 38.6270, longitude: -90.1994),
                JourneyMilestone(name: "Tulsa", distanceFromStartKm: 1_100, funFact: "Was once called the 'Oil Capital of the World'.", icon: "drop.fill", latitude: 36.1540, longitude: -95.9928),
                JourneyMilestone(name: "Amarillo", distanceFromStartKm: 1_800, funFact: "Home to Cadillac Ranch — 10 Cadillacs buried nose-first in a field.", icon: "car.fill", latitude: 35.2220, longitude: -101.8313),
                JourneyMilestone(name: "Albuquerque", distanceFromStartKm: 2_400, funFact: "Sits at 5,312 feet elevation — one of the highest major US cities.", icon: "mountain.2.fill", latitude: 35.0844, longitude: -106.6504),
                JourneyMilestone(name: "Flagstaff", distanceFromStartKm: 3_000, funFact: "Pluto was discovered here at the Lowell Observatory in 1930.", icon: "sparkles", latitude: 35.1983, longitude: -111.6513),
                JourneyMilestone(name: "Santa Monica", distanceFromStartKm: 3_940, funFact: "The official western terminus of Route 66 — 'End of the Trail'.", icon: "flag.fill", latitude: 34.0195, longitude: -118.4912),
            ]
        case .appalachianTrail:
            return [
                JourneyMilestone(name: "Springer Mountain, GA", distanceFromStartKm: 0, funFact: "The southern terminus — every thru-hiker starts or ends here.", icon: "flag.fill", latitude: 34.6268, longitude: -84.1938),
                JourneyMilestone(name: "Great Smoky Mountains", distanceFromStartKm: 320, funFact: "The most visited national park in the US with 12+ million visitors.", icon: "cloud.fog.fill", latitude: 35.6532, longitude: -83.5070),
                JourneyMilestone(name: "Shenandoah", distanceFromStartKm: 1_400, funFact: "The park has over 500 miles of trails including 101 miles of the AT.", icon: "leaf.fill", latitude: 38.2929, longitude: -78.6796),
                JourneyMilestone(name: "Harpers Ferry, WV", distanceFromStartKm: 1_700, funFact: "The psychological halfway point and home of the ATC headquarters.", icon: "building.fill", latitude: 39.3254, longitude: -77.7286),
                JourneyMilestone(name: "Delaware Water Gap", distanceFromStartKm: 2_200, funFact: "The gap was carved by the Delaware River over millions of years.", icon: "water.waves", latitude: 40.9676, longitude: -75.1438),
                JourneyMilestone(name: "White Mountains, NH", distanceFromStartKm: 2_900, funFact: "Mount Washington recorded the world's highest wind speed: 231 mph.", icon: "wind", latitude: 44.2706, longitude: -71.3033),
                JourneyMilestone(name: "Mount Katahdin, ME", distanceFromStartKm: 3_500, funFact: "The northern terminus — 'The Greatest Mountain' in the Penobscot language.", icon: "mountain.2.fill", latitude: 45.9044, longitude: -68.9213),
            ]
        case .aroundTheWorld:
            return [
                JourneyMilestone(name: "London", distanceFromStartKm: 5_570, funFact: "Big Ben is actually the name of the bell, not the tower.", icon: "bell.fill", latitude: 51.5074, longitude: -0.1278),
                JourneyMilestone(name: "Paris", distanceFromStartKm: 5_900, funFact: "The Eiffel Tower grows up to 6 inches taller in summer heat.", icon: "building.2.fill", latitude: 48.8566, longitude: 2.3522),
                JourneyMilestone(name: "Cairo", distanceFromStartKm: 9_000, funFact: "The Great Pyramid was the tallest structure for 3,800 years.", icon: "triangle.fill", latitude: 30.0444, longitude: 31.2357),
                JourneyMilestone(name: "Dubai", distanceFromStartKm: 11_000, funFact: "The Burj Khalifa is so tall you can watch 2 sunsets from it.", icon: "building.fill", latitude: 25.2048, longitude: 55.2708),
                JourneyMilestone(name: "Mumbai", distanceFromStartKm: 14_000, funFact: "Home to the world's most expensive private residence.", icon: "house.fill", latitude: 19.0760, longitude: 72.8777),
                JourneyMilestone(name: "Bangkok", distanceFromStartKm: 18_000, funFact: "Bangkok's full ceremonial name has 168 characters.", icon: "sparkles", latitude: 13.7563, longitude: 100.5018),
                JourneyMilestone(name: "Tokyo", distanceFromStartKm: 22_000, funFact: "Has more Michelin-starred restaurants than any city on Earth.", icon: "fork.knife", latitude: 35.6762, longitude: 139.6503),
                JourneyMilestone(name: "Sydney", distanceFromStartKm: 30_000, funFact: "The Opera House roof is covered with over 1 million tiles.", icon: "music.note", latitude: -33.8688, longitude: 151.2093),
                JourneyMilestone(name: "Home", distanceFromStartKm: 40_075, funFact: "You walked around the entire planet. Legendary.", icon: "globe.americas.fill", latitude: 40.7128, longitude: -74.0060),
            ]
        }
    }
}
