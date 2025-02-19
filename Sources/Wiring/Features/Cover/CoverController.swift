import Foundation

actor CoverController {
	private let name: String
	private let baseTopic: String
	private let baseConfig: Config.Cover
	private let config: Config.Cover.CoverItem

	private let stateStore: StateStore
	private let mqttClient: MQTTClient
	private let homeAssistantRestApi: HomeAssistantRestApi

	private let setPositionClientId = UUID()
	private let commandClientId = UUID()

	private var state: State.Cover {
		didSet {
			Task {
				await stateStore.setCoverState(name: name, state: state)
				await mqttClient.publish(
					topic: Self.stateTopic(baseTopic: baseTopic, name: name),
					message: state.stateMqttMessage,
					retain: true
				)
			}
		}
	}

	private var isStarted = false
	private var scheduledUpdateTask: Task<Void, Error>?

	static func stateTopic(baseTopic: String, name: String) -> String {
		"\(baseTopic)/cover/\(name)/state"
	}

	static func commandTopic(baseTopic: String, name: String) -> String {
		"\(baseTopic)/cover/\(name)/command"
	}

	static func setPositionTopic(baseTopic: String, name: String) -> String {
		"\(baseTopic)/cover/\(name)/set_position"
	}

	init(
		name: String,
		baseTopic: String,
		baseConfig: Config.Cover,
		config: Config.Cover.CoverItem,
		stateStore: StateStore,
		mqttClient: MQTTClient,
		homeAssistantRestApi: HomeAssistantRestApi,
		state: State.Cover
	) {
		self.name = name
		self.baseTopic = baseTopic
		self.baseConfig = baseConfig
		self.config = config
		self.stateStore = stateStore
		self.mqttClient = mqttClient
		self.homeAssistantRestApi = homeAssistantRestApi
		self.state = state
	}

	func start() async {
		guard !isStarted else { return }
		isStarted = true

		await mqttClient.setSubscriptions(clientId: setPositionClientId, topics: [Self.setPositionTopic(
			baseTopic: baseTopic,
			name: name
		)]) { [weak self] result in
			guard
				let self,
				case let .success(msg) = result,
				let targetPosition = try? msg.payload.getJSONDecodable(Double.self, at: 0, length: msg.payload.readableBytes)
			else { return }
			Log.debug("\(name) set position: \(targetPosition)")
			Task {
				await setTargetPosition(targetPosition)
			}
		}

		await mqttClient.setSubscriptions(clientId: commandClientId, topics: [Self.commandTopic(
			baseTopic: baseTopic,
			name: name
		)]) { [weak self] result in
			guard
				let self,
				case let .success(msg) = result,
				let command = Mqtt.Cover.Command(rawValue: String(buffer: msg.payload))
			else { return }
			Log.debug("\(name) command: \(command)")
			Task {
				switch command {
				case .close:
					await setTargetPosition(0)
				case .open:
					await setTargetPosition(100)
				case .stop:
					await stop()
				}
			}
		}
	}

	private func calculateCurrentPosition(targetPosition: Double?) -> Double {
		var currentPosition: Double = state.currentPosition
		delayCalculation: if let controlTriggeDate = state.controlTriggeDate {
			var delay = -controlTriggeDate.timeIntervalSinceNow
			Log.debug("\(name) calculation - current: \(currentPosition), original target: \(state.targetPosition), delay: \(delay)")
			guard delay > 0 else { break delayCalculation }
			if state.currentPosition < state.targetPosition {
				// opening
				if currentPosition < 1 {
					if delay <= (1 - currentPosition) * config.openSmallDuration {
						currentPosition += delay / config.openSmallDuration
						break delayCalculation
					} else {
						delay -= (1 - currentPosition) * config.openSmallDuration
						currentPosition = 1
					}
				}
				currentPosition += delay / config.openLargeDuration * 99
			} else {
				// closing
				if currentPosition > 1 {
					if delay <= (currentPosition - 1) / 99 * config.closeLargeDuration {
						currentPosition -= delay / config.closeLargeDuration * 99
						break delayCalculation
					} else {
						delay -= (currentPosition - 1) / 99 * config.closeLargeDuration
						currentPosition = 1
					}
				}
				currentPosition -= delay / config.closeSmallDuration
			}
		}
		if currentPosition > 100 {
			currentPosition = 100
		} else if currentPosition < 0 {
			currentPosition = 0
		}
		if currentPosition == targetPosition {
			if currentPosition == 100 {
				currentPosition = 99.5
			} else if currentPosition == 0 {
				currentPosition = 0.1
			}
		}
		Log.debug("\(name) current position: \(currentPosition)")
		return currentPosition
	}

	private func setTargetPosition(_ targetPosition: Double) {
		scheduledUpdateTask?.cancel()
		scheduledUpdateTask = nil

		let currentPosition = calculateCurrentPosition(targetPosition: targetPosition)
		let command: HomeAssistantRestApi.Remote.SendCommand.ServiceData.Command
		var delay: Double = 0

		if targetPosition > currentPosition {
			command = .open
			if currentPosition >= 1 {
				delay = config.openLargeDuration / 99 * (targetPosition - currentPosition)
			} else if targetPosition <= 1 {
				delay = config.openSmallDuration * (targetPosition - currentPosition)
			} else {
				delay = config.openLargeDuration / 99 * (targetPosition - 1) +
					config.openSmallDuration * (1 - currentPosition)
			}
		} else if targetPosition < currentPosition {
			command = .close
			if targetPosition >= 1 {
				delay = config.closeLargeDuration / 99 * (currentPosition - targetPosition)
			} else if currentPosition <= 1 {
				delay = config.closeSmallDuration * (currentPosition - targetPosition)
			} else {
				delay = config.closeLargeDuration / 99 * (currentPosition - 1) +
					config.closeSmallDuration * (1 - targetPosition)
			}
		} else {
			command = .stop
		}

		Log.debug("\(name) command: \(command), delay: \(delay)")
		sendCommand(command)
		state = State.Cover(
			currentPosition: currentPosition,
			targetPosition: targetPosition,
			controlTriggeDate: (command != .stop) ? Date() : nil
		)

		guard command != .stop, delay > 0 else { return }
		scheduledUpdateTask = Task {
			try await Task.sleep(for: .seconds(delay))
			self.state = State.Cover(currentPosition: targetPosition, targetPosition: targetPosition, controlTriggeDate: nil)
			if targetPosition != 100, targetPosition != 0 {
				self.sendCommand(.stop)
			}
		}
	}

	private func stop() {
		scheduledUpdateTask?.cancel()
		scheduledUpdateTask = nil

		let currentPosition = calculateCurrentPosition(targetPosition: nil)
		state = State.Cover(
			currentPosition: currentPosition,
			targetPosition: currentPosition,
			controlTriggeDate: nil
		)
		sendCommand(.stop)
	}

	private func sendCommand(_ command: HomeAssistantRestApi.Remote.SendCommand.ServiceData.Command) {
		let entityId = baseConfig.remoteEntityId
		let device = config.remoteDevice
		Task { [homeAssistantRestApi] in
			await homeAssistantRestApi.callService(HomeAssistantRestApi.Remote.SendCommand(
				serviceData: .init(
					entityId: entityId,
					device: device,
					command: command
				)
			))
		}
	}
}
