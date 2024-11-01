import Foundation

struct PresenceConfig: Codable {
	private let _espresenseDevicesBaseTopic: String?
	var espresenseDevicesBaseTopic: String { "espresense/devices" }
	private let _awayTimeout: TimeIntervalConfig?
	var awayTimeout: TimeIntervalConfig { _awayTimeout ?? TimeIntervalConfig(minutes: 5) }
	let entries: [String: PresenceItem]

	private enum CodingKeys: String, CodingKey {
		case _espresenseDevicesBaseTopic = "espresense_devices_base_topic"
		case _awayTimeout = "away_timeout"
		case entries
	}

	struct PresenceItem: Codable {
		let ip: String?
		let espresenseDevice: String?

		private enum CodingKeys: String, CodingKey {
			case ip
			case espresenseDevice = "espresense_device"
		}
	}
}
