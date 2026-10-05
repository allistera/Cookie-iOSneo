/// Why an API call failed. Cancellation is never an `APIError`; it surfaces
/// as `CancellationError` so callers do not show it as a failure.
enum APIError: Error, Equatable {
    /// The endpoint could not form a URL.
    case invalidRequest
    /// The request did not reach the server or returned a non-HTTP response.
    case transport
    /// The server rejected the token even after one renewal.
    case unauthorised
    /// The server answered with a status outside 200-299.
    case server(status: Int)
    /// The response body did not match the expected shape.
    case decoding
}
