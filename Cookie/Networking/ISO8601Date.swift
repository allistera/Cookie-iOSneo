import Foundation

/// The Workers serialise timestamps as ISO 8601 UTC, with fractional seconds
/// when the value came through JavaScript's `Date` and without otherwise.
enum ISO8601Date {
    static func parse(_ text: String) -> Date? {
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let whole = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
        // The first parse may legitimately fail; the second is the fallback.
        return (try? fractional.parse(text)) ?? (try? whole.parse(text))
    }
}

extension JSONDecoder {
    /// Decodes the Workers' snake_case JSON with ISO 8601 dates.
    static func cookieAPI() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = ISO8601Date.parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO 8601 date: \(text)")
            }
            return date
        }
        return decoder
    }
}
