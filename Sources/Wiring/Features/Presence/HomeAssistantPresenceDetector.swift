actor HomeAssistantPresenceDetector {
	private let webSocket: HomeAssistantWebSocket
	private let presenceDetectorAggregator: PresenceDetectorAggregator

	private let entityId: String
	private let atHomeState: String

	private var isStarted = false

	init(
		webSocket: HomeAssistantWebSocket,
		presenceDetectorAggregator: PresenceDetectorAggregator,
		entityId: String,
		atHomeState: String,
	) {
		self.webSocket = webSocket
		self.presenceDetectorAggregator = presenceDetectorAggregator
		self.entityId = entityId
		self.atHomeState = atHomeState
	}

	func start() async {
		guard !isStarted else { return }
		isStarted = true

		await webSocket.addSubscription(entityId: entityId) { [weak self] state in
			guard let self else { return }
			await presenceDetectorAggregator.setHomeAssistantPresence(state == atHomeState)
		}
	}
}
