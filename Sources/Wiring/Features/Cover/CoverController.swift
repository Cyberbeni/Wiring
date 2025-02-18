actor CoverController {
	let name: String
	let baseTopic: String
	let config: Config.Cover.CoverItem

	let stateStore: StateStore
	let mqttClient: MQTTClient
	let homeAssistantRestApi: HomeAssistantRestApi

	var state: State.Cover {
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
		config: Config.Cover.CoverItem,
		stateStore: StateStore,
		mqttClient: MQTTClient,
		homeAssistantRestApi: HomeAssistantRestApi,
		state: State.Cover
	) {
		self.name = name
		self.baseTopic = baseTopic
		self.config = config
		self.stateStore = stateStore
		self.mqttClient = mqttClient
		self.homeAssistantRestApi = homeAssistantRestApi
		self.state = state
	}
}
