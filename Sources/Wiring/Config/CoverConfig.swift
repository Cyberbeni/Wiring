import Foundation

extension Config {
	struct Cover: Decodable {
		let remoteEntityId: String
		let entries: [String: CoverItem]

		struct CoverItem: Decodable {
			let remoteDevice: String
			let deviceClass: Wiring.Mqtt.Cover.DeviceClass?
			let openDuration: TimeInterval
			let openSmallDuration: TimeInterval?
			let closeDuration: TimeInterval
			let closeSmallDuration: TimeInterval?
		}
	}
}
