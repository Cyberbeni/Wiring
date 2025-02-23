import Foundation

actor CoverController {
	private let name: String
	private let baseTopic: String
	private let remoteEntityId: String
	private let remoteDevice: String
	private let deviceClass: Wiring.Mqtt.Cover.DeviceClass?
	private let openSmallDuration: Double
	private let openLargeDuration: Double
	private let closeSmallDuration: Double
	private let closeLargeDuration: Double

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
	private let children: [CoverController]

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
		remoteEntityId: String,
		remoteDevice: String,
		deviceClass: Wiring.Mqtt.Cover.DeviceClass?,
		openSmallDuration: Double,
		openLargeDuration: Double,
		closeSmallDuration: Double,
		closeLargeDuration: Double,
		stateStore: StateStore,
		mqttClient: MQTTClient,
		homeAssistantRestApi: HomeAssistantRestApi,
		state: State.Cover,
		children: [CoverController]
	) {
		self.name = name
		self.baseTopic = baseTopic
		self.remoteEntityId = remoteEntityId
		self.remoteDevice = remoteDevice
		self.deviceClass = deviceClass
		self.openSmallDuration = openSmallDuration
		self.openLargeDuration = openLargeDuration
		self.closeSmallDuration = closeSmallDuration
		self.closeLargeDuration = closeLargeDuration
		self.stateStore = stateStore
		self.mqttClient = mqttClient
		self.homeAssistantRestApi = homeAssistantRestApi
		self.state = state
		self.children = children
	}

	func start() async {
		guard !isStarted else { return }
		isStarted = true

		let setPositionTopic = Self.setPositionTopic(baseTopic: baseTopic, name: name)
		await mqttClient.setSubscriptions(clientId: setPositionClientId, topics: [setPositionTopic]) { [weak self] result in
			guard
				let self,
				case let .success(msg) = result,
				msg.topicName == setPositionTopic,
				let targetPosition = try? msg.payload.getJSONDecodable(Double.self, at: 0, length: msg.payload.readableBytes)
			else { return }
			Log.debug("\(name) set position: \(targetPosition)")
			Task {
				await setTargetPosition(targetPosition)
			}
		}

		let commandTopic = Self.commandTopic(baseTopic: baseTopic, name: name)
		await mqttClient.setSubscriptions(clientId: commandClientId, topics: [commandTopic]) { [weak self] result in
			guard
				let self,
				case let .success(msg) = result,
				msg.topicName == commandTopic,
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
					if delay <= (1 - currentPosition) * openSmallDuration {
						currentPosition += delay / openSmallDuration
						break delayCalculation
					} else {
						delay -= (1 - currentPosition) * openSmallDuration
						currentPosition = 1
					}
				}
				currentPosition += delay / openLargeDuration * 99
			} else {
				// closing
				if currentPosition > 1 {
					if delay <= (currentPosition - 1) / 99 * closeLargeDuration {
						currentPosition -= delay / closeLargeDuration * 99
						break delayCalculation
					} else {
						delay -= (currentPosition - 1) / 99 * closeLargeDuration
						currentPosition = 1
					}
				}
				currentPosition -= delay / closeSmallDuration
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

	func setTargetPosition(_ targetPosition: Double, parentControl: Bool = false) async {
		scheduledUpdateTask?.cancel()
		scheduledUpdateTask = nil

		let currentPosition = calculateCurrentPosition(targetPosition: targetPosition)
		let command: HomeAssistantRestApi.Remote.SendCommand.ServiceData.Command
		var delay: Double = 0

		if targetPosition > currentPosition {
			command = .open
			if currentPosition >= 1 {
				delay = openLargeDuration / 99 * (targetPosition - currentPosition)
			} else if targetPosition <= 1 {
				delay = openSmallDuration * (targetPosition - currentPosition)
			} else {
				delay = openLargeDuration / 99 * (targetPosition - 1) +
					openSmallDuration * (1 - currentPosition)
			}
		} else if targetPosition < currentPosition {
			command = .close
			if targetPosition >= 1 {
				delay = closeLargeDuration / 99 * (currentPosition - targetPosition)
			} else if currentPosition <= 1 {
				delay = closeSmallDuration * (currentPosition - targetPosition)
			} else {
				delay = closeLargeDuration / 99 * (currentPosition - 1) +
					closeSmallDuration * (1 - targetPosition)
			}
		} else {
			command = .stop
		}

		Log.debug("\(name) command: \(command), delay: \(delay)")
		if !parentControl {
			sendCommand(command)
		}
		for child in children {
			switch command {
				case .open:
					await child.setTargetPosition(100, parentControl: true)
				case .close:
					await child.setTargetPosition(0, parentControl: true)
				case .stop:
					await child.stop(parentControl: true)
			}
		}
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
				if !parentControl {
					self.sendCommand(.stop)
				}
				for child in children {
					await child.stop(parentControl: true)
				}
			}
		}
	}

	func stop(parentControl: Bool = false) async {
		scheduledUpdateTask?.cancel()
		scheduledUpdateTask = nil

		let currentPosition = calculateCurrentPosition(targetPosition: nil)
		state = State.Cover(
			currentPosition: currentPosition,
			targetPosition: currentPosition,
			controlTriggeDate: nil
		)
		if !parentControl {
			sendCommand(.stop)
		}
		for child in children {
			await child.stop(parentControl: true)
		}
	}

	private func sendCommand(_ command: HomeAssistantRestApi.Remote.SendCommand.ServiceData.Command) {
		let entityId = remoteEntityId
		let device = remoteDevice
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
