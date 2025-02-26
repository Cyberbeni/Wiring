import Foundation

extension Config {
	struct HomeAssistant: Decodable {
		let baseAddress: String
		let accessToken: String
	}
}
