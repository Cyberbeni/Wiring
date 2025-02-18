actor CoverController {
	let name: String
	let config: Config.Cover.CoverItem

	let stateStore: StateStore
	let mqttClient: MQTTClient
	let homeAssistantRestApi: HomeAssistantRestApi

	var state: State.Cover {
		didSet {
			Task {
				await stateStore.setCoverState(name: name, state: state)
				// await mqttClient.publish(topic: String, message: Encodable, retain: Bool)
			}
		}
	}

	init(
		name: String,
		config: Config.Cover.CoverItem,
		stateStore: StateStore,
		mqttClient: MQTTClient,
		homeAssistantRestApi: HomeAssistantRestApi,
		state: State.Cover
	) {
		self.name = name
		self.config = config
		self.stateStore = stateStore
		self.mqttClient = mqttClient
		self.homeAssistantRestApi = homeAssistantRestApi
		self.state = state
	}
}
