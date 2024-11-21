import Foundation

extension Config {
	struct WebSocket: Decodable {
		private let _scheme: String?
		var scheme: String { _scheme ?? "ws" }
		let host: String
		let port: Int
		private let _path: String?
		var path: String { _path ?? "/api/websocket" }

		private enum CodingKeys: String, CodingKey {
			case _scheme = "scheme"
			case host
			case port
			case _path = "path"
		}
	}
}
