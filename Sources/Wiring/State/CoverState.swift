import Foundation

extension State {
	struct Cover: Codable {
		let currentPosition: Double
		let targetPosition: Double
		let controlTriggeDate: Date?
	}
}
