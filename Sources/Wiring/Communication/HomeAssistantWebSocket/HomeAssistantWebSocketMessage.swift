import Foundation

extension HomeAssistantWebSocket {
	enum Message: Codable {
		typealias ID = UInt

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

		case callService(CallService)
		case result(Result)

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
			case "call_service":
				self = try .callService(CallService(from: decoder))
			case "result":
				self = try .result(Result(from: decoder))
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
			case let .callService(data):
				try container.encode("call_service", forKey: .type)
				try data.encode(to: encoder)
			case let .result(data):
				try container.encode("result", forKey: .type)
				try data.encode(to: encoder)
			}
		}

		private enum TypeCodingKey: String, CodingKey {
			case type
		}
	}
}

extension HomeAssistantWebSocket.Message {
	struct Auth: Codable {
		let accessToken: String
	}

	struct CallService: Codable {
		let id: ID
		let domain: String
		let service: String
		let serviceData: [String: String]
		let target: Target

		struct Target: Codable {
			let entityId: String
		}
	}

	struct Result: Codable {
		let id: ID?
		let success: Bool
		let error: Error?

		struct Error: Codable {
			let code: String
			let message: String
		}
	}
}
