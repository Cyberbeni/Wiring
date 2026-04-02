// TODO: use NIOFoundationEssentialsCompat once released: https://github.com/apple/swift-nio/pull/3567
// https://github.com/apple/swift-nio/blob/d80f3bac98e43b910bda7fb6b42b7e7dc013613f/Sources/NIOFoundationCompat/ByteBuffer-foundation.swift#L107
// https://github.com/apple/swift-nio/blob/d80f3bac98e43b910bda7fb6b42b7e7dc013613f/Sources/NIOFoundationCompat/Codable%2BByteBuffer.swift
import NIO

public extension ByteBuffer {
	/// Controls how bytes are transferred between `ByteBuffer` and other storage types.
	enum ByteTransferStrategy: Sendable {
		/// Force a copy of the bytes.
		case copy

		/// Do not copy the bytes if at all possible.
		case noCopy

		/// Use a heuristic to decide whether to copy the bytes or not.
		case automatic
	}

	/// Return `length` bytes starting at `index` and return the result as `Data`. This will not change the reader index.
	/// The selected bytes must be readable or else `nil` will be returned.
	///
	/// - Parameters:
	///   - index: The starting index of the bytes of interest into the `ByteBuffer`
	///   - length: The number of bytes of interest
	///   - byteTransferStrategy: Controls how to transfer the bytes. See `ByteTransferStrategy` for an explanation
	///                             of the options.
	/// - Returns: A `Data` value containing the bytes of interest or `nil` if the selected bytes are not readable.
	func getData(at index: Int, length: Int, byteTransferStrategy: ByteTransferStrategy) -> Data? {
		let index = index - readerIndex
		guard index >= 0, length >= 0, index <= readableBytes - length else {
			return nil
		}
		let doCopy: Bool
		switch byteTransferStrategy {
		case .copy:
			doCopy = true
		case .noCopy:
			doCopy = false
		case .automatic:
			doCopy = length <= 256 * 1024
		}

		return withUnsafeReadableBytesWithStorageManagement { ptr, storageRef in
			if doCopy {
				return Data(
					bytes: UnsafeMutableRawPointer(mutating: ptr.baseAddress!.advanced(by: index)),
					count: Int(length),
				)
			} else {
				let storage = storageRef.takeUnretainedValue()
				return Data(
					bytesNoCopy: UnsafeMutableRawPointer(mutating: ptr.baseAddress!.advanced(by: index)),
					count: Int(length),
					deallocator: .custom { _, _ in withExtendedLifetime(storage) {} },
				)
			}
		}
	}

	/// Attempts to decode the `length` bytes from `index` using the `JSONDecoder` `decoder` as `T`.
	///
	/// - Parameters:
	///    - type: The type type that is attempted to be decoded.
	///    - decoder: The `JSONDecoder` that is used for the decoding.
	///    - index: The index of the first byte to decode.
	///    - length: The number of bytes to decode.
	/// - Returns: The decoded value if successful or `nil` if there are not enough readable bytes available.
	@inlinable
	func getJSONDecodable<T: Decodable>(
		_: T.Type,
		decoder: JSONDecoder = JSONDecoder(),
		at index: Int,
		length: Int,
	) throws -> T? {
		guard let data = getData(at: index, length: length, byteTransferStrategy: .noCopy) else {
			return nil
		}
		return try decoder.decode(T.self, from: data)
	}

	/// Encodes `value` using the `JSONEncoder` `encoder` and set the resulting bytes into this `ByteBuffer` at the
	/// given `index`.
	///
	/// - Note: The `writerIndex` remains unchanged.
	///
	/// - Parameters:
	///   - value: An `Encodable` value to encode.
	///   - encoder: The `JSONEncoder` to encode `value` with.
	///   - index: The starting index of the bytes for the value into the `ByteBuffer`.
	/// - Returns: The number of bytes written.
	@inlinable
	@discardableResult
	mutating func setJSONEncodable(
		_ value: some Encodable,
		encoder: JSONEncoder = JSONEncoder(),
		at index: Int,
	) throws -> Int {
		let data = try encoder.encode(value)
		return setBytes(data, at: index)
	}

	/// Encodes `value` using the `JSONEncoder` `encoder` and writes the resulting bytes into this `ByteBuffer`.
	///
	/// If successful, this will move the writer index forward by the number of bytes written.
	///
	/// - Parameters:
	///   - value: An `Encodable` value to encode.
	///   - encoder: The `JSONEncoder` to encode `value` with.
	/// - Returns: The number of bytes written.
	@inlinable
	@discardableResult
	mutating func writeJSONEncodable(
		_ value: some Encodable,
		encoder: JSONEncoder = JSONEncoder(),
	) throws -> Int {
		let result = try setJSONEncodable(value, encoder: encoder, at: writerIndex)
		moveWriterIndex(forwardBy: result)
		return result
	}
}
