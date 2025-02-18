import Foundation

enum Config {
	static func jsonDecoder() -> JSONDecoder {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		decoder.allowsJSON5 = true
		return decoder
	}
}
