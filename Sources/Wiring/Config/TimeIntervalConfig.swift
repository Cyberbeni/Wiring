import Foundation

extension Config {
	struct TimeInterval: Decodable {
		let seconds: Double

		init(from decoder: any Decoder) throws {
			let container = try decoder.singleValueContainer()
			if let doubleValue = try? container.decode(Double.self) {
				guard doubleValue > 0 else {
					throw DecodingError.dataCorruptedError(in: container, debugDescription: "TimeInterval must be positive")
				}
				seconds = doubleValue
			} else {
				let stringValue = try container.decode(String.self)
				let parts = stringValue.split(separator: ":").compactMap(Double.init)
				let doubleValue: Double = parts.reduce(0) { acc, value in acc * 60 + value }
				guard doubleValue > 0 else {
					throw DecodingError.dataCorruptedError(in: container, debugDescription: "TimeInterval must be positive")
				}
				seconds = doubleValue
			}
		}

		init(seconds: Double) { self.seconds = seconds }
		init(minutes: Double) { seconds = minutes * 60 }
	}
}
