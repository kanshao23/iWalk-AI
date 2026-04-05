import SwiftUI

@Observable
final class BadgesViewModel {
    var badges = Badge.mockBadges
    var challenges = Challenge.mockChallenges
    var leaderboard = LeaderboardEntry.mockEntries

    // UI States
    var showLeaderboard = false
    var selectedBadge: Badge?
    var expandedChallengeId: UUID?
    var challengeAnimated: [UUID: Bool] = [:]

    var userRank: LeaderboardEntry? {
        leaderboard.first(where: \.isCurrentUser)
    }

    var totalParticipants: Int { 25_000 }

    var unlockedBadges: [Badge] {
        badges.filter(\.isUnlocked)
    }

    var lockedBadges: [Badge] {
        badges.filter { !$0.isUnlocked }
    }

    func animateOnAppear() {
        for challenge in challenges {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.8)) {
                    self.challengeAnimated[challenge.id] = true
                }
            }
        }
    }

    func toggleChallenge(_ challenge: Challenge) {
        if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                challenges[index].isJoined.toggle()
            }
        }
    }

    func toggleExpandChallenge(_ challenge: Challenge) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedChallengeId == challenge.id {
                expandedChallengeId = nil
            } else {
                expandedChallengeId = challenge.id
            }
        }
    }
}
