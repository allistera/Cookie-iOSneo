import Foundation

/// Authenticated JSON requests to Cookie's Worker APIs.
struct APIClient: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let tokens: TokenProvider
    private let transport: Transport

    init(
        tokens: TokenProvider,
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }
    ) {
        self.tokens = tokens
        self.transport = transport
    }

    /// Fetches and decodes `endpoint`. A 401 forces one token renewal and one
    /// retry; a second 401 invalidates the session.
    func get<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
        guard let url = endpoint.url else { throw APIError.invalidRequest }

        var (data, status) = try await send(url, token: try await tokens.current())
        if status == 401 {
            (data, status) = try await send(url, token: try await tokens.renewed())
            if status == 401 {
                await tokens.invalidate()
                throw APIError.unauthorised
            }
        }
        guard (200..<300).contains(status) else { throw APIError.server(status: status) }

        do {
            return try JSONDecoder.cookieAPI().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func send(_ url: URL, token: String) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await transport(request)
            guard let http = response as? HTTPURLResponse else { throw APIError.transport }
            return (data, http.statusCode)
        } catch let error as APIError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.transport
        }
    }
}
