import Foundation

enum AppDeepLinkRoute: Equatable {
    case home
    case activeWalk
    case pauseWalk
    case endWalk
}

enum AppDeepLinkRouter {
    static func route(for url: URL) -> AppDeepLinkRoute? {
        guard url.scheme?.lowercased() == "iwalkai" else { return nil }

        switch url.host?.lowercased() {
        case "home":
            return .home
        case "active-walk":
            return .activeWalk
        case "pause-walk":
            return .pauseWalk
        case "end-walk":
            return .endWalk
        default:
            return nil
        }
    }
}
