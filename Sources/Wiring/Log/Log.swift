import Foundation

enum Log {
	// Only modified on main thread before any concurrency happens
	nonisolated(unsafe) static var enableDebugLogging = false
	private static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		if let localeId = ProcessInfo.processInfo.environment["LANG"] {
			formatter.locale = Locale(identifier: localeId)
		}
		formatter.dateStyle = .short
		formatter.timeStyle = .medium
		return formatter
	}()

	static func debug(_ message: @autoclosure () -> String, file: StaticString = #file) {
		guard enableDebugLogging else { return }
		print("\(dateFormatter.string(from: Date.now)) debug: \(file) - \(message())")
	}

	static func info(_ message: String) {
		print("\(dateFormatter.string(from: Date.now)) info: \(message)")
	}

	static func error(_ message: String, file: StaticString = #file, line: Int = #line, function: StaticString = #function) {
		print("\(dateFormatter.string(from: Date.now)) error: \(file):\(line) - \(function) - \(message)")
	}

	static func error(_ error: Error, file: StaticString = #file, line: Int = #line, function: StaticString = #function) {
		print("\(dateFormatter.string(from: Date.now)) error: \(file):\(line) - \(function) - \(error)")
	}
}
