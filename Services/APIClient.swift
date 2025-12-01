import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case decodingError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .httpError(let code, let body):
            return "HTTP \(code): " + body
        case .decodingError:
            return "Failed to decode server response."
        case .unknown(let msg):
            return msg
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    func request<T: Decodable>(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        accessToken: String? = nil
    ) async throws -> T {
        let url = edulensAPI(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            let encoded = try JSONEncoder().encode(AnyEncodable(body))
            req.httpBody = encoded
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.unknown("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, text)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        _encode = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

struct EmptyResponse: Decodable {}
