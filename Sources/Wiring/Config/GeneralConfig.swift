import Foundation

extension Config {
	struct General: Codable {
		let mqtt: Mqtt
		let enableDebugLogging: Bool
	}
}
