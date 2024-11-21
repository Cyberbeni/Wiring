import Foundation

@propertyWrapper
struct Sensitive<Value>:
	CustomStringConvertible,
	CustomDebugStringConvertible,
	CustomReflectable
{
	var wrappedValue: Value

	init(wrappedValue: Value) {
		self.wrappedValue = wrappedValue
	}

	var description: String {
		"<sensitive>"
	}

	var debugDescription: String {
		"<sensitive>"
	}

	var customMirror: Mirror {
		Mirror(reflecting: "<sensitive>")
	}
}

extension Sensitive: Decodable where Value: Decodable {
	init(from decoder: Decoder) throws {
		wrappedValue = try Value(from: decoder)
	}
}

extension Sensitive: Encodable where Value: Encodable {
	func encode(to encoder: Encoder) throws {
		try wrappedValue.encode(to: encoder)
	}
}

extension Sensitive: Sendable where Value: Sendable {}
