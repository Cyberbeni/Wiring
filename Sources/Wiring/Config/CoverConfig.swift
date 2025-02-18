import Foundation

extension Config {
	struct Cover: Decodable {
		let remoteEntityId: String
		let entries: [String: CoverItem]

		struct CoverItem: Decodable {
			let remoteDevice: String
			let deviceClass: Wiring.Mqtt.Cover.DeviceClass?
			let openDuration: TimeInterval
			var openSmallDuration: TimeInterval { _openSmallDuration ?? TimeInterval(seconds: openDuration.seconds / 100) }
			private let _openSmallDuration: TimeInterval?
			let closeDuration: TimeInterval
			var closeSmallDuration: TimeInterval { _closeSmallDuration ?? TimeInterval(seconds: closeDuration.seconds / 100) }
			private let _closeSmallDuration: TimeInterval?

			enum CodingKeys: String, CodingKey {
				case remoteDevice
				case deviceClass
				case openDuration
				case _openSmallDuration = "openSmallDuration"
				case closeDuration
				case _closeSmallDuration = "closeSmallDuration"
			}
		}
	}
}
