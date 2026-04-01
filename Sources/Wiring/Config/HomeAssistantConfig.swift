extension Config {
	struct HomeAssistant: Decodable {
		let baseAddress: URL
		let accessToken: String
	}
}
