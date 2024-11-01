import Foundation

struct MqttConfig: Codable {
	let host: String
	let port: Int
	let user: String?
	let password: String?
	private let _rootTopic: String?

	var rootTopic: String { _rootTopic ?? "wiring" }

	private enum CodingKeys: String, CodingKey {
		case host
		case port
		case user
		case password
		case _rootTopic = "root_topic"
	}
}