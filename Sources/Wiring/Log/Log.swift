enum Log {
	// Only modified on main thread before any concurrency happens
	nonisolated(unsafe) static var enableDebugLogging = false

	static func debug(_ message: @autoclosure () -> String, file: StaticString = #file) {
		guard enableDebugLogging else { return }
		print("debug: \(file) - \(message())")
	}

	static func info(_ message: String) {
		print("info: \(message)")
	}

	static func error(_ message: String, file: StaticString = #file, line: Int = #line, function: StaticString = #function) {
		print("error: \(file):\(line) - \(function) - \(message)")
	}

	static func error(_ error: Error, file: StaticString = #file, line: Int = #line, function: StaticString = #function) {
		print("error: \(file):\(line) - \(function) - \(error)")
	}
}
