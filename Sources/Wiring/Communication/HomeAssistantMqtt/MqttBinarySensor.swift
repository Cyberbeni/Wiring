import Foundation

extension Mqtt {
	/// https://www.home-assistant.io/integrations/binary_sensor.mqtt/
	struct BinarySensor: Encodable {
		let availabilityTopic: String?
		let device: Device
		let deviceClass: DeviceClass
		/// Can be set to `.explicitNone` if only the device name is relevant.
		let name: String??
		let payloadOff: String?
		let payloadOn: String?
		let stateTopic: String
		let uniqueId: String

		enum Payload: String {
			case on = "ON"
			case off = "OFF"

			init(_ bool: Bool?) {
				if bool == true {
					self = .on
				} else {
					self = .off
				}
			}
		}

		/// https://www.home-assistant.io/integrations/binary_sensor/#device-class
		enum DeviceClass: String, Encodable {
			case battery
			case batteryCharging = "battery_charging"
			case carbonMonoxide = "carbon_monoxide"
			case cold
			case connectivity
			case door
			case garageDoor = "garage_door"
			case gas
			case heat
			case light
			case lock
			case moisture
			case motion
			case moving
			case occupancy
			case opening
			case plug
			case power
			case presence
			case problem
			case running
			case safety
			case smoke
			case sound
			case tamper
			case update
			case vibration
			case window
		}
	}
}
