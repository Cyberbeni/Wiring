import Foundation

extension State {
	struct Cover: Codable {
		let currentPosition: Double
		let targetPosition: Double
		let controlTriggeDate: Date?

		var asInitialState: Cover {
			if currentPosition < targetPosition {
				Cover(currentPosition: 100, targetPosition: 100, controlTriggeDate: nil)
			} else if currentPosition > targetPosition {
				Cover(currentPosition: 0, targetPosition: 0, controlTriggeDate: nil)
			} else {
				self
			}
		}

		var stateMqttMessage: Mqtt.Cover.StateMessage {
			let roundedCurrentPosition = if currentPosition > 0, currentPosition < 1 {
				1
			} else if currentPosition < 100, currentPosition > 99 {
				99
			} else {
				Int(round(currentPosition))
			}
			let roundedTargetPosition = if targetPosition > 0, targetPosition < 1 {
				1
			} else if targetPosition < 100, targetPosition > 99 {
				99
			} else {
				Int(round(targetPosition))
			}
			let state: Mqtt.Cover.StateMessage.State = if currentPosition > targetPosition {
				.closing
			} else if currentPosition < targetPosition {
				.opening
			} else if currentPosition == 0 {
				.closed
			} else {
				.open
			}
			return Mqtt.Cover.StateMessage(currentPosition: roundedCurrentPosition, targetPosition: roundedTargetPosition, state: state)
		}
	}
}
