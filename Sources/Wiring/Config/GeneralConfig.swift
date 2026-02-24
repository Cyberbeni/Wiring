import Foundation

extension Config {
	struct General: Decodable {
		let mqtt: Mqtt
		let homeAssistant: HomeAssistant?
		let webSocket: Config.WebSocket?
		private let _publishServerState: Bool?
		var publishServerState: Bool { _publishServerState ?? true }
		private let _enableDebugLogging: Bool?
		var enableDebugLogging: Bool { _enableDebugLogging ?? false }

		private enum CodingKeys: String, CodingKey {
			case mqtt
			case homeAssistant
			case webSocket
			case _publishServerState = "publishServerState"
			case _enableDebugLogging = "enableDebugLogging"
		}
	}
}
