import Foundation

extension Mqtt {
	/// https://www.home-assistant.io/integrations/device_tracker/
	/// https://www.home-assistant.io/integrations/device_tracker.mqtt/
	struct DeviceTracker: Encodable {
		let availabilityTopic: String?
		let device: Device
		/// Can be set to `.explicitNone` if only the device name is relevant.
		let name: String??
		let payloadHome: String?
		let payloadNotHome: String?
		let sourceType: SourceType
		let stateTopic: String
		let uniqueId: String

		/// https://www.home-assistant.io/integrations/device_tracker.mqtt/#source_type
		enum SourceType: String, Encodable {
			case gps
			case router
			case bluetooth
			case bluetoothLe = "bluetooth_le"
		}
	}
}
