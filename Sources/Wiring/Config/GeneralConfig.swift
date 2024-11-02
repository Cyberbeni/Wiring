import Foundation

extension Config {
	struct General: Decodable {
		let mqtt: Mqtt
		private let _enableDebugLogging: Bool?
		var enableDebugLogging: Bool { _enableDebugLogging ?? false }

		private enum CodingKeys: String, CodingKey {
			case mqtt
			case _enableDebugLogging = "enableDebugLogging"
		}
	}
}
