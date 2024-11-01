import Foundation

struct PresenceConfig: Codable {
	let espresenceDevicesTopic: String?
	let awayTimeout: TimeIntervalConfig
	let items: [String: PresenceItem]

	private enum CodingKeys: String, CodingKey {
		case espresenceDevicesTopic = "espresence_devices_topic"
		case awayTimeout = "away_timeout"
		case items
	}

	struct PresenceItem: Codable {
		let ip: String?
		let espresenceDevice: String?

		private enum CodingKeys: String, CodingKey {
			case ip
			case espresenceDevice = "espresence_device"
		}
	}
}
