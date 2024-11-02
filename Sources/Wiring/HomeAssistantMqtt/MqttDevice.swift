import Foundation

extension Mqtt {
	struct Device: Encodable {
		let identifiers: String
		let name: String?
	}
}
