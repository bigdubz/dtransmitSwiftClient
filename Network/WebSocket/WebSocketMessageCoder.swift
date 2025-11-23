import Foundation

enum WebSocketMessageCoder {

    static func encode(_ message: ClientMessage) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []

        do {
            let data = try encoder.encode(message)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Failed to encode ClientMessage: \(error)")
            return nil
        }
    }


    static func decode(_ text: String) -> ServerMessage? {
        guard let data = text.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()

        do {
            let message = try decoder.decode(ServerMessage.self, from: data)
            return message
        } catch {
            print("Failed to decode ServerMessage: \(error)")
            print("Raw text: \(text)")
            return nil
        }
    }
}