import Foundation

enum HomeAssistantWebSocketMessage: Codable {
	static func jsonDecoder() -> JSONDecoder {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return decoder
	}

	static func jsonEncoder() -> JSONEncoder {
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
		return encoder
	}

	case authRequired
	case auth(Auth)
	case authOk
	case authInvalid

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: TypeCodingKey.self)
		let type = try container.decode(String.self, forKey: .type)
		switch type {
		case "auth_required":
			self = .authRequired
		case "auth":
			self = try .auth(Auth(from: decoder))
		case "auth_ok":
			self = .authOk
		case "auth_invalid":
			self = .authInvalid
		default:
			throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported type: '\(type)'")
		}
	}

	func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: TypeCodingKey.self)
		switch self {
		case .authRequired:
			try container.encode("auth_required", forKey: .type)
		case let .auth(data):
			try container.encode("auth", forKey: .type)
			try data.encode(to: encoder)
		case .authOk:
			try container.encode("auth_ok", forKey: .type)
		case .authInvalid:
			try container.encode("auth_invalid", forKey: .type)
		}
	}

	private enum TypeCodingKey: String, CodingKey {
		case type
	}
}

extension HomeAssistantWebSocketMessage {
	struct Auth: Codable {
		let accessToken: String
	}
}
