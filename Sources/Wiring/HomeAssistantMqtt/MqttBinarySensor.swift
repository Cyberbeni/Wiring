import Foundation

extension Mqtt {
	/// https://www.home-assistant.io/integrations/binary_sensor.mqtt/
	struct BinarySensor: Codable {
		let availabilityTopic: String
		let deviceClass: DeviceClass?
		let stateTopic: String
		let name: String

		enum Payload: String, Codable {
			case on = "ON"
			case off = "OFF"
		}

		/// https://www.home-assistant.io/integrations/binary_sensor/#device-class
		enum DeviceClass: String, Codable {
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
