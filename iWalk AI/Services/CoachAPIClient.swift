import Foundation

enum CoachAPIError: LocalizedError {
    case invalidResponseStatus(Int)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidResponseStatus(let code):
            return "coach-api-status-\(code)"
        case .invalidPayload:
            return "coach-api-invalid-payload"
        }
    }
}

struct CoachAPIClient {
    struct CoachContext: Encodable {
        // Existing
        let steps: Int
        let streak: Int
        let goal: Int
        let userName: String
        // Walk history summary (zero/unknown for new users with no history)
        let totalWalks: Int
        let avgPaceMinPerKm: Double
        let bestTimeOfDay: String   // "morning" | "afternoon" | "evening" | "unknown"
        let paceTrend: String       // "improving" | "stable" | "declining"
        let thisWeekWalks: Int
        let lastWeekWalks: Int
    }

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        let messages: [ChatMessage]
        let context: CoachContext
    }

    private struct ResponseBody: Decodable {
        let reply: String
    }

    // 专用 session，避免与 URLSession.shared 共享连接状态
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    func sendMessage(
        history: [ChatMessage],
        context: CoachContext
    ) async throws -> String {
        do {
            return try await performRequest(history: history, context: context)
        } catch {
            guard Self.shouldRetry(error: error) else {
                throw error
            }

            print("[CoachAPI] First attempt failed (\(error)), retrying...")
            return try await performRequest(history: history, context: context)
        }
    }

    static func shouldRetry(error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }

        switch urlError.code {
        case .timedOut,
             .networkConnectionLost,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .notConnectedToInternet:
            return true
        default:
            return false
        }
    }

    private func performRequest(
        history: [ChatMessage],
        context: CoachContext
    ) async throws -> String {
        var request = URLRequest(url: AppConfig.coachWorkerURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(messages: history, context: context)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await Self.session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            throw CoachAPIError.invalidResponseStatus(http.statusCode)
        }

        guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            throw CoachAPIError.invalidPayload
        }
        return decoded.reply
    }
}
