enum Log {
	// Only modified on main thread before any concurrency happens
	nonisolated(unsafe) static var enableDebugLogging = false

	static func debug(_ message: @autoclosure @escaping () -> String) {
		guard enableDebugLogging else { return }
		print(message())
	}

	static func info(_ message: String) {
		print(message)
	}

	static func error(_ message: String) {
		print(message)
	}
}
