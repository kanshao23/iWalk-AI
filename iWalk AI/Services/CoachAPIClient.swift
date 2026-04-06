import Foundation

struct CoachAPIClient {
    struct CoachContext: Encodable {
        let steps: Int
        let streak: Int
        let goal: Int
        let userName: String
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

    private let session = URLSession.shared

    func sendMessage(
        history: [ChatMessage],
        context: CoachContext
    ) async throws -> String {
        var request = URLRequest(url: AppConfig.coachWorkerURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = RequestBody(messages: history, context: context)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return decoded.reply
    }
}
