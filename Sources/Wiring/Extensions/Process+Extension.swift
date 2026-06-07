import Foundation

extension Process {
	convenience init(_ arguments: [String]) {
		self.init()
		executableURL = URL(filePath: "/usr/bin/env")
		self.arguments = arguments
	}

	func setIO(
		standardInput: Pipe? = nil,
		standardOutput: Pipe? = nil,
		standardError: Pipe? = nil,
	) {
		self.standardInput = standardInput
		self.standardOutput = standardOutput
		self.standardError = standardError
	}
}
