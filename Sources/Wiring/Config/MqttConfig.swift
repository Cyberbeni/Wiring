import Foundation

extension Config {
	struct Mqtt: Decodable {
		let host: String
		let port: Int
		let user: String?
		let password: String?
		private let _baseTopic: String?
		var baseTopic: String { _baseTopic ?? "wiring" }
		private let _homeAssistantBaseTopic: String?
		var homeAssistantBaseTopic: String { _homeAssistantBaseTopic ?? "homeassistant" }

		private enum CodingKeys: String, CodingKey {
			case host
			case port
			case user
			case password
			case _baseTopic = "baseTopic"
			case _homeAssistantBaseTopic = "homeAssistantBaseTopic"
		}
	}
}
