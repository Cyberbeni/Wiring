import Foundation

extension Config {
	struct General: Decodable {
		let mqtt: Mqtt
		let enableDebugLogging: Bool
	}
}
