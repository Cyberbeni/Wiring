import Foundation

extension Mqtt {
	struct Device: Encodable {
		let identifiers: String
		let manufacturer: String = "Wiring"
		let model: String
		let name: String?
		let viaDevice: String?
	}
}
