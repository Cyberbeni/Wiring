import Foundation

extension Config {
	struct Presence: Codable {
		private let _espresenseDevicesBaseTopic: String?
		var espresenseDevicesBaseTopic: String { "espresense/devices" }
		private let _pingInterval: TimeInterval?
		var pingInterval: TimeInterval { _pingInterval ?? TimeInterval(seconds: 5) }
		private let _arpInterval: TimeInterval?
		var arpInterval: TimeInterval { _arpInterval ?? TimeInterval(seconds: 5) }
		private let _awayTimeout: TimeInterval?
		var awayTimeout: TimeInterval { _awayTimeout ?? TimeInterval(minutes: 5) }
		let entries: [String: PresenceItem]

		private enum CodingKeys: String, CodingKey {
			case _espresenseDevicesBaseTopic = "espresenseDevicesBaseTopic"
			case _pingInterval = "pingInterval"
			case _arpInterval = "arpInterval"
			case _awayTimeout = "awayTimeout"
			case entries
		}

		struct PresenceItem: Codable {
			let ip: String?
			let espresenseDevice: String?
		}
	}
}
