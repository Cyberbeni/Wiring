import Foundation

extension Mqtt {
	/// https://www.home-assistant.io/integrations/cover.mqtt/
	struct Cover: Encodable {
		let availabilityTopic: String?
		let commandTopic: String
		let device: Device
		let deviceClass: DeviceClass?
		/// Can be set to `.explicitNone` if only the device name is relevant.
		let name: String??
		let platform: Platform
		let positionTemplate: String
		let positionTopic: String
		let setPositionTemplate: String
		let setPositionTopic: String
		let stateTopic: String
		let uniqueId: String
		/// Defines a template that can be used to extract the payload for the `state_topic` topic.
		let valueTemplate: String

		struct StateMessage: Encodable {
			let currentPosition: Double
			let targetPosition: Double
			let state: State

			enum State: String, Encodable {
				case closed
				case closing
				case open
				case opening
			}
		}

		enum Command: String, Decodable {
			case open = "OPEN"
			case close = "CLOSE"
			case stop = "STOP"
		}

		/// https://www.home-assistant.io/integrations/cover/#device-class
		enum DeviceClass: String, Codable {
			case awning
			case blind
			case curtain
			case damper
			case door
			case garage
			case gate
			case shade
			case shutter
			case window
		}

		enum Platform: String, Encodable {
			case cover
		}
	}
}
