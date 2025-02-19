import Foundation

extension Config {
	struct Cover: Decodable {
		let remoteEntityId: String
		let entries: [String: CoverItem]

		struct CoverItem: Decodable {
			let remoteDevice: String
			let deviceClass: Wiring.Mqtt.Cover.DeviceClass?
			private let openDuration: TimeInterval
			var openSmallDuration: Double { _openSmallDuration?.seconds ?? (openDuration.seconds / 100) }
			var openLargeDuration: Double { openDuration.seconds - openSmallDuration }
			private let _openSmallDuration: TimeInterval?
			private let closeDuration: TimeInterval
			var closeSmallDuration: Double { _closeSmallDuration?.seconds ?? (closeDuration.seconds / 100) }
			var closeLargeDuration: Double { closeDuration.seconds - closeSmallDuration }
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
