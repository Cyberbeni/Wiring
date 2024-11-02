import Foundation

extension Config {
	struct Mqtt: Codable {
		let host: String
		let port: Int
		let user: String?
		let password: String?
		private let _baseTopic: String?
		var baseTopic: String { _baseTopic ?? "wiring" }

		private enum CodingKeys: String, CodingKey {
			case host
			case port
			case user
			case password
			case _baseTopic = "base_topic"
		}
	}
}
