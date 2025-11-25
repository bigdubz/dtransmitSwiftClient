import Foundation


struct LoginRequestBody: Encodable {
    let userId: String
    let password: String
}

struct LoginResponseBody: Decodable {
    let token: String
    let userId: String
}


enum AuthAPI {
    // MARK: CHANGE HERE
    static let baseURL = URL(string: "https://lonely-variety-stolen-cherry.trycloudflare.com")!

    static func login(userId: String, password: String) async throws -> LoginResponseBody {
        let url = baseURL.appendingPathComponent("login")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = LoginRequestBody(userId: userId, password: password)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AuthError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let login = try JSONDecoder().decode(LoginResponseBody.self, from: data)
            return login
        } catch {
            throw AuthError.decodingFailed(error)
        }
    }
}


enum AuthError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed(Error)
}
